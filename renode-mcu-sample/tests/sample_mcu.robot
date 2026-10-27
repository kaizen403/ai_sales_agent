*** Settings ***
Suite Setup       Setup
Suite Teardown    Teardown
Test Setup        Reset Emulation
Test Teardown     Test Teardown
Resource          ${RENODEKEYWORDS}
Library           String

*** Variables ***
${UART}                   sysbus.uart0
${PROMPT_READY}           READY SampleMCU
${AI_BASE}                0x40003000
${RENODE_SAMPLE_DIR}      ${CURDIR}${/}..${/}renode
${FIRMWARE_ELF}           ${CURDIR}${/}..${/}firmware${/}build${/}sample_mcu.elf

*** Keywords ***
Prepare Machine
    Execute Command             path add @${RENODE_SAMPLE_DIR}
    Execute Command             $bin = @${FIRMWARE_ELF}
    Execute Command             include @${RENODE_SAMPLE_DIR}${/}sample_mcu.resc
    Create Terminal Tester      ${UART}
    ${do0}=                     Create LED Tester  sysbus.gpio_out.do0   defaultTimeout=2
    ${do1}=                     Create LED Tester  sysbus.gpio_out.do1   defaultTimeout=2
    ${do7}=                     Create LED Tester  sysbus.gpio_out.do7   defaultTimeout=2
    ${led0}=                    Create LED Tester  sysbus.gpio_out.led0  defaultTimeout=2
    ${led1}=                    Create LED Tester  sysbus.gpio_out.led1  defaultTimeout=2
    ${led2}=                    Create LED Tester  sysbus.gpio_out.led2  defaultTimeout=2
    Set Test Variable           ${do0}
    Set Test Variable           ${do1}
    Set Test Variable           ${do7}
    Set Test Variable           ${led0}
    Set Test Variable           ${led1}
    Set Test Variable           ${led2}

Boot Firmware
    Start Emulation
    Wait For Line On Uart       ${PROMPT_READY}  timeout=5  pauseEmulation=false

# Feed a UART command via Monitor WriteChar (more reliable than Write Line To Uart
# for polled NS16550 in this sample).
Uart Command
    [Arguments]                 ${cmd}
    Execute Command             start
    ${chars}=                   Get Length  ${cmd}
    FOR    ${i}    IN RANGE    ${chars}
        ${j}=                   Evaluate  ${i} + 1
        ${ch}=                  Get Substring  ${cmd}  ${i}  ${j}
        ${code}=                Evaluate  ord("""${ch}""")
        Execute Command         uart0 WriteChar ${code}
    END
    Execute Command             uart0 WriteChar 0x0A


Set Digital Input
    [Arguments]                 ${index}  ${pressed}
    IF    ${pressed}
        Execute Command         sysbus.gpio_in.di${index} Press
    ELSE
        Execute Command         sysbus.gpio_in.di${index} Release
    END

Set Analog Input
    [Arguments]                 ${index}  ${value}
    ${addr}=                    Evaluate  ${AI_BASE} + 4 * int(${index})
    Execute Command             sysbus WriteDoubleWord ${addr} ${value}

Clear All Digital Inputs
    FOR    ${i}    IN RANGE    0    8
        Set Digital Input       ${i}  ${False}
    END

*** Test Cases ***
Firmware Boots And Answers Ping
    Prepare Machine
    Boot Firmware
    Uart Command                PING
    Wait For Line On Uart       OK PONG  timeout=5  pauseEmulation=false

Mirror Mode Maps DI To DO
    Prepare Machine
    Boot Firmware
    Uart Command                MODE MIRROR
    Wait For Line On Uart       OK MODE MIRROR  pauseEmulation=false
    Clear All Digital Inputs
    Uart Command                PROCESS
    Wait For Line On Uart       OK PROCESS  pauseEmulation=false
    Assert LED State            false  testerId=${do0}
    Assert LED State            false  testerId=${do7}

    Set Digital Input           0  ${True}
    Uart Command                PROCESS
    Wait For Line On Uart       OK PROCESS  pauseEmulation=false
    Assert LED State            true   testerId=${do0}
    Assert LED State            true   testerId=${led0}
    Assert LED State            true   testerId=${led1}

    Set Digital Input           0  ${False}
    Set Digital Input           7  ${True}
    Uart Command                PROCESS
    Wait For Line On Uart       OK PROCESS  pauseEmulation=false
    Assert LED State            false  testerId=${do0}
    Assert LED State            true   testerId=${do7}

Threshold Mode Requires AI Above Threshold
    Prepare Machine
    Boot Firmware
    Uart Command                MODE THRESHOLD
    Wait For Line On Uart       OK MODE THRESHOLD  pauseEmulation=false
    Uart Command                THRESHOLD 2000
    Wait For Line On Uart       OK THRESHOLD 2000  pauseEmulation=false
    Assert LED State            true   testerId=${led2}

    Clear All Digital Inputs
    Set Analog Input            1  100
    Set Digital Input           1  ${True}
    Uart Command                PROCESS
    Wait For Line On Uart       OK PROCESS  pauseEmulation=false
    Assert LED State            false  testerId=${do1}

    Set Analog Input            1  3000
    Uart Command                PROCESS
    Wait For Line On Uart       OK PROCESS  pauseEmulation=false
    Assert LED State            true   testerId=${do1}
    Assert LED State            true   testerId=${led1}

UART Status Reports Mode And IO
    Prepare Machine
    Boot Firmware
    Uart Command                MODE MIRROR
    Wait For Line On Uart       OK MODE MIRROR  pauseEmulation=false
    Clear All Digital Inputs
    Set Digital Input           3  ${True}
    Uart Command                STATUS
    Wait For Line On Uart       OK STATUS mode=MIRROR  timeout=5  pauseEmulation=false
    Uart Command                GETDI
    Wait For Line On Uart       OK DI 0x08  pauseEmulation=false
    Uart Command                GETDO
    Wait For Line On Uart       OK DO 0x08  pauseEmulation=false

UART Getai Reflects Written Channels
    Prepare Machine
    Boot Firmware
    Set Analog Input            0  10
    Set Analog Input            7  4095
    Uart Command                GETAI
    Wait For Line On Uart       OK AI 10 0 0 0 0 0 0 4095  pauseEmulation=false
