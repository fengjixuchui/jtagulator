{
    MIT License
    
    Copyright (C) 2020  Adam Green (https://github.com/adamgreen)
    
    Permission is hereby granted, free of charge, to any person obtaining a copy
    of this software and associated documentation files (the "Software"), to deal
    in the Software without restriction, including without limitation the rights
    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
    copies of the Software, and to permit persons to whom the Software is
    furnished to do so, subject to the following conditions:
    
    The above copyright notice and this permission notice shall be included in all
    copies or substantial portions of the Software.
    
    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
    SOFTWARE.
}
' Unit tests for the SWD (ARM's Serial Wire Debug) modules.
' The SWDHost module is used by the JTAGulator to probe for potential
' SWD devices connected to its pins.
' The SWDTarget module is currently only used to unit test the SWDHost
' module and doesn't get compiled into the actual JTAGulator code.

CON
    ' System Clock Frequency set to 80MHz.
    _CLKFREQ = 80_000_000
    _CLKMODE = XTAL1 | PLL16X

OBJ
    tst: "UnitTest"
    host: "SWDHost"
    target: "SWDTarget"
    capture: "SWDCapture"
    
VAR
    LONG m_buffer[capture#MAX_CAPTURE_LONGS]
        
PUB Main | status, value, bitCount
    tst.init
    target.init
    capture.init
    host.init
    
    
    ' --------------------------------------------------------------------------------
    ' Testing of SWDTarget module's detection of line reset (50 SWCLKs of SWDIO 
    ' held high.)
    ' --------------------------------------------------------------------------------
    tst.start(STRING("No line reset"))
        target.start(0, 1)
        tst.checkLong(@clockCountsMsg, target.clockCounts, 0)
        tst.checkLong(@lineResetMsg, target.inLineResetState, FALSE)
        target.stop
    tst.end

    tst.start(STRING("Bad line reset - 1 too few clocks"))
        target.start(0, 1)
        ' Perform a line reset incorrectly, with 1 too few clock cycles (49 instead of 50).
        OUTA[0..1]~
        DIRA[0..1]~~
        cyclePin(0, 49)
        ' Should fail to register a line detect.
        tst.checkLong(@clockCountsMsg, target.clockCounts, 49)
        tst.checkLong(@lineResetMsg, target.inLineResetState, FALSE)
        target.stop
    tst.end

    tst.start(STRING("Bad line reset - 1 too few high SWDIO"))
        target.start(0, 1)
        ' Perform 49 clocks with SWDIO high.
        OUTA[0..1]~
        DIRA[0..1]~~
        cyclePin(0, 49)
        ' Incorrectly set SWDIO low for this last clock cycle.
        OUTA[1]~
        cyclePin(0, 1)
        ' Should fail to register a line detect.
        tst.checkLong(@clockCountsMsg, target.clockCounts, 50)
        tst.checkLong(@lineResetMsg, target.inLineResetState, FALSE)
        target.stop
    tst.end

    tst.start(STRING("Line reset - 1 low SWDIO in middle"))
        target.start(0, 1)
        ' Perform 49 clocks with SWDIO high.
        OUTA[0..1]~
        DIRA[0..1]~~
        cyclePin(0, 49)
        ' Set SWDIO low for this middle clock cycle.
        OUTA[1]~
        cyclePin(0, 1)
        ' Do almost a full 50 clocks with SWDIO high to complete a good line reset.
        OUTA[1]~~
        cyclePin(0, 49)
        ' Should still not be in line reset state until another clock edge is seen.
        tst.checkLong(@lineResetMsg, target.inLineResetState, FALSE)
        cyclePin(0, 1)
        ' Second set should register a line detect.
        tst.checkLong(@clockCountsMsg, target.clockCounts, 100)
        tst.checkLong(@lineResetMsg, target.inLineResetState, TRUE)
        target.stop
    tst.end


    ' --------------------------------------------------------------------------------
    ' Tests of host.readDP()
    ' --------------------------------------------------------------------------------
    tst.start(STRING("readDP(host#DP_IDCODE, ...) #1 @ 1kHz"))
        target.start(0, 1)
        target.setIDCODE($12345678)
        host.config(0, 1, 1000)
        status := host.readDP(host#DP_IDCODE, @value)
        tst.checkLong(@statusMsg, status, host#RESP_OK)
        tst.checkLong(@valueMsg, value, $12345678)
        tst.checkLong(@freqMsg, target.frequency, 1000)
        target.stop
    tst.end

    tst.start(STRING("readDP(host#DP_IDCODE, ...) #2 @ 1024Hz"))
        target.start(0, 1)
        target.setIDCODE($87654321)
        host.config(0, 1, 1024)
        status := host.readDP(host#DP_IDCODE, @value)
        tst.checkLong(@statusMsg, status, host#RESP_OK)
        tst.checkLong(@valueMsg, value, $87654321)
        tst.checkLong(@freqMsg, target.frequency, 1024)
        target.stop
    tst.end

    tst.start(STRING("Capture readDP(host#DP_IDCODE, ...)"))
        target.start(0, 1)
        target.setIDCODE($12345678)
        capture.start(0, 1)
        host.config(0, 1, host#SWD_SLOW_CLOCK_RATE)
        host.readDP(host#DP_IDCODE, @value)
        bitCount := capture.getCapturedBits(@m_buffer)
        ' 8-bit packet request + 1-bit turn-around + 3-bit ack + 32-bit data +
        ' 1-bit parity + 1-bit turn-around.
        tst.checkLong(@bitCountMsg, bitCount, 8+1+3+32+1+1)
        '                                         $4   $5   $6   $7   $8  ack t  packet
        tst.checkLong(@buffer0Msg, m_buffer[0], %0100_0101_0110_0111_1000_001_1_10100101) 
        '                                        t p  $1   $2   $3
        tst.checkLong(@buffer1Msg, m_buffer[1], %0_1_0001_0010_0011) 
        tst.checkLong(@buffer2Msg, m_buffer[2], 0) 
        tst.checkLong(@buffer3Msg, m_buffer[3], 0) 
        capture.stop
        target.stop
    tst.end

    tst.start(STRING("Call readDP() twice"))
        target.start(0, 1)
        target.setIDCODE($12345678)
        host.config(0, 1, host#SWD_SLOW_CLOCK_RATE)
        status := host.readDP(host#DP_IDCODE, @value)
        tst.checkLong(@statusMsg, status, host#RESP_OK)
        tst.checkLong(@valueMsg, value, $12345678)
        target.setIDCODE($87654321)
        status := host.readDP(host#DP_IDCODE, @value)
        tst.checkLong(@statusMsg, status, host#RESP_OK)
        tst.checkLong(@valueMsg, value, $87654321)
        target.stop
    tst.end

    tst.start(STRING("readDP w/ parity error"))
        target.start(0, 1)
        target.setIDCODE($12345678)
        target.introduceParityError(TRUE)
        host.config(0, 1, host#SWD_SLOW_CLOCK_RATE)
        status := host.readDP(host#DP_IDCODE, @value)
        tst.checkLong(@statusMsg, status, host#RESP_PARITY)
        target.stop
    tst.end

    tst.start(STRING("readDP w/ failure response"))
        target.start(0, 1)
        target.setIDCODE($12345678)
        target.introduceResponseError(host#RESP_FAULT)
        value := $baadf00d
        host.config(0, 1, host#SWD_SLOW_CLOCK_RATE)
        status := host.readDP(host#DP_IDCODE, @value)
        tst.checkLong(@statusMsg, status, host#RESP_FAULT)
        ' No data should be read on failure.
        tst.checkLong(@valueMsg, value, $baadf00d)
        target.stop
    tst.end


    ' --------------------------------------------------------------------------------
    ' Tests of resetSwJtagAndReadIdCode() & resetAndReadIdCode()
    ' --------------------------------------------------------------------------------
    tst.start(STRING("resetSwJtagAndReadIdCode"))
        target.start(0, 1)
        target.setIDCODE($12345678)
        capture.start(0, 1)
        host.config(0, 1, 1000)
        status := host.resetSwJtagAndReadIdCode(@value)
        tst.checkLong(@statusMsg, status, host#RESP_OK)
        tst.checkLong(@valueMsg, value, $12345678)
        bitCount := capture.getCapturedBits(@m_buffer)
        ' 51-bit reset + 16-bit switch + 51-bit reset + 8-bit idle + 8-bit packet request +
        ' 1-bit turn-around + 3-bit ack + 32-bit data + 1-bit parity + 1-bit turn-around.
        tst.checkLong(@bitCountMsg, bitCount, 51+16+51+8+8+1+3+32+1+1)
        ' First 32-bits of reset.                 reset
        tst.checkLong(@buffer0Msg, m_buffer[0], $FFFFFFFF) 
        ' Last 19-bits of reset, first 13-bits of switch command.
        '                                           switch              reset
        tst.checkLong(@buffer1Msg, m_buffer[1], %0_0111_1001_1110_1111111111111111111) 
        ' Last 3-bits of switch command and first 29-bits of second reset.
        '                                                    reset             switch
        tst.checkLong(@buffer2Msg, m_buffer[2], %11111111111111111111111111111_111)
        ' Last 22-bits of reset command, 8-bits of idle, start=1, nDP=0
        '                                        ds   idle         reset
        tst.checkLong(@buffer3Msg, m_buffer[3], %01_00000000_1111111111111111111111) 
        ' Packet bits: Read=1, 2 address bits=%00, parity=1, stop=0, park=1, turn=1, ack=%001, 22-bits of IDCODE.
        '                                        $3  $4    $5  $6   $7   $8  ack t pspaar               
        tst.checkLong(@buffer4Msg, m_buffer[4], %11_0100_0101_0110_0111_1000_001_1_101001) 
        capture.stop
        target.stop
    tst.end

    tst.start(STRING("resetAndReadIdCode"))
        target.start(0, 1)
        target.setIDCODE($12345678)
        capture.start(0, 1)
        host.config(0, 1, 1000)
        status := host.resetAndReadIdCode(@value)
        tst.checkLong(@statusMsg, status, host#RESP_OK)
        tst.checkLong(@valueMsg, value, $12345678)
        bitCount := capture.getCapturedBits(@m_buffer)
        ' 51-bit reset + 8-bit idle + 8-bit packet request + 1-bit turn-around + 
        ' 3-bit ack + 32-bit data + 1-bit parity + 1-bit turn-around.
        tst.checkLong(@bitCountMsg, bitCount, 51+8+8+1+3+32+1+1)
        ' First 32-bits of reset.                 reset
        tst.checkLong(@buffer0Msg, m_buffer[0], $FFFFFFFF) 
        ' Last 19-bits of reset, 8-bits of idle, start=1, nDP=0, read=1, address=%00,
        '                                        packet   idle          reset
        tst.checkLong(@buffer1Msg, m_buffer[1], %00101_00000000_1111111111111111111) 
        ' parity=1, stop=0, park=1, turn=1, ack=%001, and 25-bits of IDCODE.
        '                                        $2  $3   $4   $5   $6   $7   $8  ack t  packet
        tst.checkLong(@buffer2Msg, m_buffer[2], %0_0011_0100_0101_0110_0111_1000_001_1_101) 
        ' Last 7-bits of IDCODE, parity, and turn-around.
        '                                        t p  $1  $2
        tst.checkLong(@buffer3Msg, m_buffer[3], %0_1_0001_001) 
        capture.stop
        target.stop
    tst.end
    
    tst.start(STRING("resetSwJtagAndReadIdCode @ highest rate w/o hanging"))
        value := $baadf00d
        host.config(0, 1, host#SWD_FASTEST_CLOCK_RATE)
        status := host.resetSwJtagAndReadIdCode(@value)
        ' Will fail to actually read since nothing is responding.
        tst.checkLong(@statusMsg, status, %111)
        tst.checkLong(@valueMsg, value, $baadf00d)
    tst.end

    host.uninit
    tst.stats

PRI cyclePin(pin, count)
    REPEAT count
        ' SWCLK Low
        OUTA[pin]~
        WAITCNT(CONSTANT(_CLKFREQ/2000) + CNT)
        ' SWCLK High
        OUTA[pin]~~
        WAITCNT(CONSTANT(_CLKFREQ/2000) + CNT)

DAT
    clockCountsMsg BYTE "target.clockCounts", 0
    lineResetMsg BYTE "target.inLineResetState", 0
    statusMsg BYTE "status", 0
    valueMsg BYTE "value", 0
    freqMsg BYTE "frequency", 0
    bitCountMsg BYTE "bitCount", 0
    buffer0Msg BYTE "m_buffer[0]", 0
    buffer1Msg BYTE "m_buffer[1]", 0
    buffer2Msg BYTE "m_buffer[2]", 0
    buffer3Msg BYTE "m_buffer[3]", 0
    buffer4Msg BYTE "m_buffer[4]", 0
    