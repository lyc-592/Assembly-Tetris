; =========================================================================
; Tetris Final Fixed Version
; 1. 修复旋转逻辑 Bug (保存新角度)
; 2. 包含之前所有的 Unicode/正方形/防抖修复
; =========================================================================

.386
.model flat, stdcall
option casemap:none

; --- 链接库 ---
includelib D:\masm32\lib\kernel32.lib
includelib D:\masm32\lib\user32.lib
includelib D:\masm32\lib\msvcrt.lib

; --- 结构体 ---
SMALL_RECT STRUCT
  Left      WORD ?
  Top       WORD ?
  Right     WORD ?
  Bottom    WORD ?
SMALL_RECT ENDS

COORD STRUCT
  X WORD ?
  Y WORD ?
COORD ENDS

CHAR_INFO_UNION UNION
  UnicodeChar WORD ?
  AsciiChar   BYTE ?
CHAR_INFO_UNION ENDS

CHAR_INFO STRUCT
  Char       CHAR_INFO_UNION <>
  Attributes WORD ?
CHAR_INFO ENDS

; --- 函数原型 ---
ExitProcess         PROTO :DWORD
Sleep               PROTO :DWORD
GetStdHandle        PROTO :DWORD
SetConsoleTitleA    PROTO :DWORD
GetTickCount        PROTO
GetAsyncKeyState    PROTO :DWORD
WriteConsoleOutputW PROTO :DWORD, :DWORD, :DWORD, :DWORD, :DWORD

rand        PROTO C
srand       PROTO C :DWORD
wsprintfA   PROTO C :DWORD, :VARARG

; --- 常量 ---
STD_OUTPUT_HANDLE equ -11
VK_LEFT           equ 25h
VK_UP             equ 26h
VK_RIGHT          equ 27h
VK_DOWN           equ 28h
VK_ESCAPE         equ 1Bh

; 游戏参数
BOARD_WIDTH     equ 12
BOARD_HEIGHT    equ 22
SCREEN_WIDTH    equ 60
SCREEN_HEIGHT   equ 30

.data
    szTitle         db "Tetris Final Fixed", 0
    szScoreFmt      db "Score: %d", 0
    
    hStdOut         DWORD ?
    bGameRunning    DWORD 1
    dwTimer         DWORD 0
    nSpeed          DWORD 10
    nScore          DWORD 0

    nCurrentPiece   DWORD 0
    nCurrentRot     DWORD 0
    nPieceX         DWORD 0
    nPieceY         DWORD 0

    bRotateHeld     DWORD 0 

    Board           BYTE BOARD_WIDTH * BOARD_HEIGHT dup(0)

    ; 方块定义
    Tetrominoes     BYTE 0,0,1,0, 0,0,1,0, 0,0,1,0, 0,0,1,0
                    BYTE 0,0,0,0, 1,1,1,1, 0,0,0,0, 0,0,0,0
                    BYTE 0,0,1,0, 0,0,1,0, 0,0,1,0, 0,0,1,0
                    BYTE 0,0,0,0, 1,1,1,1, 0,0,0,0, 0,0,0,0
                    
    Tetrominoes_1   BYTE 0,1,1,0, 0,1,1,0, 0,0,0,0, 0,0,0,0
                    BYTE 0,1,1,0, 0,1,1,0, 0,0,0,0, 0,0,0,0
                    BYTE 0,1,1,0, 0,1,1,0, 0,0,0,0, 0,0,0,0
                    BYTE 0,1,1,0, 0,1,1,0, 0,0,0,0, 0,0,0,0
                    
    Tetrominoes_2   BYTE 0,1,0,0, 1,1,1,0, 0,0,0,0, 0,0,0,0
                    BYTE 0,1,0,0, 0,1,1,0, 0,1,0,0, 0,0,0,0
                    BYTE 0,0,0,0, 1,1,1,0, 0,1,0,0, 0,0,0,0
                    BYTE 0,1,0,0, 1,1,0,0, 0,1,0,0, 0,0,0,0
                    
    Tetrominoes_3   BYTE 0,1,1,0, 1,1,0,0, 0,0,0,0, 0,0,0,0
                    BYTE 0,1,0,0, 0,1,1,0, 0,0,1,0, 0,0,0,0
                    BYTE 0,1,1,0, 1,1,0,0, 0,0,0,0, 0,0,0,0
                    BYTE 0,1,0,0, 0,1,1,0, 0,0,1,0, 0,0,0,0
                    
    Tetrominoes_4   BYTE 1,1,0,0, 0,1,1,0, 0,0,0,0, 0,0,0,0
                    BYTE 0,0,1,0, 0,1,1,0, 0,1,0,0, 0,0,0,0
                    BYTE 1,1,0,0, 0,1,1,0, 0,0,0,0, 0,0,0,0
                    BYTE 0,0,1,0, 0,1,1,0, 0,1,0,0, 0,0,0,0
                    
    Tetrominoes_5   BYTE 0,1,0,0, 0,1,0,0, 1,1,0,0, 0,0,0,0
                    BYTE 1,0,0,0, 1,1,1,0, 0,0,0,0, 0,0,0,0
                    BYTE 0,1,1,0, 0,1,0,0, 0,1,0,0, 0,0,0,0
                    BYTE 0,0,0,0, 1,1,1,0, 0,0,1,0, 0,0,0,0
                    
    Tetrominoes_6   BYTE 0,1,0,0, 0,1,0,0, 0,1,1,0, 0,0,0,0
                    BYTE 0,0,0,0, 1,1,1,0, 1,0,0,0, 0,0,0,0
                    BYTE 1,1,0,0, 0,1,0,0, 0,1,0,0, 0,0,0,0
                    BYTE 0,0,1,0, 1,1,1,0, 0,0,0,0, 0,0,0,0

    pShapes         DWORD offset Tetrominoes, offset Tetrominoes_1, offset Tetrominoes_2, offset Tetrominoes_3
                    DWORD offset Tetrominoes_4, offset Tetrominoes_5, offset Tetrominoes_6

    rectWindow      SMALL_RECT <0, 0, SCREEN_WIDTH-1, SCREEN_HEIGHT-1>
    coordBufferSize COORD <SCREEN_WIDTH, SCREEN_HEIGHT>
    coordZero       COORD <0, 0>
    lpScreenBuffer  CHAR_INFO SCREEN_WIDTH * SCREEN_HEIGHT dup(<>)
    szScoreBuffer   BYTE 32 dup(0)

.code

GetRandom proc range:DWORD
    invoke rand
    cdq
    mov ecx, range
    idiv ecx
    mov eax, edx
    ret
GetRandom endp

CheckCollision proc nPX:DWORD, nPY:DWORD, nPiece:DWORD, nRot:DWORD
    LOCAL i:DWORD, px:DWORD, py:DWORD
    
    mov eax, nPiece
    mov edx, [pShapes + eax*4]
    mov eax, nRot
    shl eax, 4
    add edx, eax

    mov i, 0
    .WHILE i < 16
        mov eax, i
        mov cl, byte ptr [edx + eax]
        .IF cl != 0
            mov eax, i
            and eax, 3
            add eax, nPX
            mov px, eax
            mov eax, i
            shr eax, 2
            add eax, nPY
            mov py, eax
            mov eax, py
            imul eax, BOARD_WIDTH
            add eax, px
            mov cl, byte ptr [Board + eax]
            .IF cl != 0
                mov eax, 1
                ret
            .ENDIF
        .ENDIF
        inc i
    .ENDW
    mov eax, 0
    ret
CheckCollision endp

LockPiece proc
    LOCAL i:DWORD, px:DWORD, py:DWORD
    
    mov eax, nCurrentPiece
    mov edx, [pShapes + eax*4]
    mov eax, nCurrentRot
    shl eax, 4
    add edx, eax

    mov i, 0
    .WHILE i < 16
        mov eax, i
        mov cl, byte ptr [edx + eax]
        .IF cl != 0
            mov eax, i
            and eax, 3
            add eax, nPieceX
            mov px, eax
            mov eax, i
            shr eax, 2
            add eax, nPieceY
            mov py, eax
            mov eax, py
            imul eax, BOARD_WIDTH
            add eax, px
            mov bl, 1
            mov byte ptr [Board + eax], bl
        .ENDIF
        inc i
    .ENDW
    ret
LockPiece endp

RemoveLines proc
    LOCAL y:DWORD, x:DWORD, bLineFull:BYTE

    mov y, BOARD_HEIGHT - 2 
    .WHILE y > 0
        mov bLineFull, 1
        mov x, 1
        .WHILE x < BOARD_WIDTH - 1
            mov eax, y
            imul eax, BOARD_WIDTH
            add eax, x
            mov cl, byte ptr [Board + eax]
            .IF cl == 0
                mov bLineFull, 0
                .BREAK
            .ENDIF
            inc x
        .ENDW

        .IF bLineFull == 1
            add nScore, 100
            mov ecx, y
            .WHILE ecx > 0
                mov x, 1
                .WHILE x < BOARD_WIDTH - 1
                    mov eax, ecx
                    dec eax
                    imul eax, BOARD_WIDTH
                    add eax, x
                    mov bl, byte ptr [Board + eax]
                    mov eax, ecx
                    imul eax, BOARD_WIDTH
                    add eax, x
                    mov byte ptr [Board + eax], bl
                    inc x
                .ENDW
                dec ecx
            .ENDW
        .ELSE
            dec y
        .ENDIF
    .ENDW
    ret
RemoveLines endp

SpawnPiece proc
    invoke GetRandom, 7
    mov nCurrentPiece, eax
    mov nCurrentRot, 0
    mov nPieceX, 4
    mov nPieceY, 0
    invoke CheckCollision, nPieceX, nPieceY, nCurrentPiece, nCurrentRot
    .IF eax == 1
        mov bGameRunning, 0 
    .ENDIF
    ret
SpawnPiece endp

InitBoard proc
    LOCAL x:DWORD, y:DWORD
    mov y, 0
    .WHILE y < BOARD_HEIGHT
        mov x, 0
        .WHILE x < BOARD_WIDTH
            .IF x == 0 || x == BOARD_WIDTH - 1 || y == BOARD_HEIGHT - 1
                mov eax, y
                imul eax, BOARD_WIDTH
                add eax, x
                mov byte ptr [Board + eax], 9 
            .ENDIF
            inc x
        .ENDW
        inc y
    .ENDW
    ret
InitBoard endp

; ==========================================================
; ProcessInput 关键修复：正确保存和恢复旋转角度
; ==========================================================
ProcessInput proc
    invoke GetAsyncKeyState, VK_RIGHT
    .IF eax != 0
        mov eax, nPieceX
        inc eax
        invoke CheckCollision, eax, nPieceY, nCurrentPiece, nCurrentRot
        .IF eax == 0
            inc nPieceX
        .ENDIF
    .ENDIF

    invoke GetAsyncKeyState, VK_LEFT
    .IF eax != 0
        mov eax, nPieceX
        dec eax
        invoke CheckCollision, eax, nPieceY, nCurrentPiece, nCurrentRot
        .IF eax == 0
            dec nPieceX
        .ENDIF
    .ENDIF

    invoke GetAsyncKeyState, VK_DOWN
    .IF eax != 0
        mov eax, nPieceY
        inc eax
        invoke CheckCollision, nPieceX, eax, nCurrentPiece, nCurrentRot
        .IF eax == 0
            inc nPieceY
        .ENDIF
    .ENDIF

    ; --- 旋转逻辑 (修复版) ---
    invoke GetAsyncKeyState, VK_UP
    test eax, 8000h
    jz KeyUp
    
        cmp bRotateHeld, 1
        je DoneRotate

        ; 1. 计算新角度
        mov eax, nCurrentRot
        inc eax
        and eax, 3
        
        ; 2. !!! 关键：将新角度压入堆栈保存 !!!
        push eax 
        
        ; 3. 调用检测 (EAX作为参数传入)
        invoke CheckCollision, nPieceX, nPieceY, nCurrentPiece, eax
        
        ; 4. !!! 关键：将新角度从堆栈弹出到 EDX (因为 EAX 已经被覆盖了) !!!
        pop edx 
        
        ; 5. 如果 EAX (返回值) == 0，则更新角度为 EDX (保存的新角度)
        .IF eax == 0
             mov nCurrentRot, edx
        .ENDIF
        
        mov bRotateHeld, 1
        jmp DoneRotate

    KeyUp:
        mov bRotateHeld, 0
        
    DoneRotate:
    
    invoke GetAsyncKeyState, VK_ESCAPE
    .IF eax != 0
        mov bGameRunning, 0
    .ENDIF
    ret
ProcessInput endp

DrawGame proc
    LOCAL i:DWORD, x:DWORD, y:DWORD, boardVal:BYTE
    LOCAL charCode:WORD, attr:WORD

    mov ecx, SCREEN_WIDTH * SCREEN_HEIGHT
    mov esi, offset lpScreenBuffer
    .WHILE ecx > 0
        mov word ptr [esi], 20h
        mov word ptr [esi+2], 07h
        add esi, 4
        dec ecx
    .ENDW

    mov y, 0
    .WHILE y < BOARD_HEIGHT
        mov x, 0
        .WHILE x < BOARD_WIDTH
            mov eax, y
            imul eax, BOARD_WIDTH
            add eax, x
            mov cl, byte ptr [Board + eax]
            mov boardVal, cl
            
            .IF boardVal == 0
                mov charCode, 20h
                mov attr, 0
            .ELSEIF boardVal == 9
                mov charCode, 23h
                mov attr, 08h
            .ELSE
                mov charCode, 2588h
                mov attr, 0Fh
            .ENDIF
            
            mov eax, y
            add eax, 2
            imul eax, SCREEN_WIDTH
            
            mov ebx, x
            shl ebx, 1
            add ebx, 2
            
            add eax, ebx
            shl eax, 2
            
            mov esi, offset lpScreenBuffer
            add esi, eax
            
            mov ax, charCode
            mov word ptr [esi], ax
            mov ax, attr
            mov word ptr [esi+2], ax
            mov ax, charCode
            mov word ptr [esi+4], ax
            mov ax, attr
            mov word ptr [esi+6], ax
            
            inc x
        .ENDW
        inc y
    .ENDW

    mov eax, nCurrentPiece
    mov edx, [pShapes + eax*4]
    mov eax, nCurrentRot
    shl eax, 4
    add edx, eax

    mov i, 0
    .WHILE i < 16
        mov eax, i
        mov cl, byte ptr [edx + eax]
        .IF cl != 0
            mov eax, i
            and eax, 3
            add eax, nPieceX
            mov ebx, eax
            mov eax, i
            shr eax, 2
            add eax, nPieceY
            
            add eax, 2
            imul eax, SCREEN_WIDTH
            
            shl ebx, 1
            add ebx, 2
            
            add eax, ebx
            shl eax, 2
            
            mov esi, offset lpScreenBuffer
            add esi, eax
            
            mov word ptr [esi], 2588h
            mov word ptr [esi+2], 0Eh
            mov word ptr [esi+4], 2588h
            mov word ptr [esi+6], 0Eh
        .ENDIF
        inc i
    .ENDW
    
    invoke wsprintfA, addr szScoreBuffer, addr szScoreFmt, nScore
    mov esi, offset szScoreBuffer
    mov edi, offset lpScreenBuffer
    add edi, ((5 * SCREEN_WIDTH) + 30) * 4
    .WHILE byte ptr [esi] != 0
        mov al, [esi]
        mov byte ptr [edi], al
        mov word ptr [edi+2], 0Fh
        inc esi
        add edi, 4
    .ENDW
    
    invoke WriteConsoleOutputW, hStdOut, addr lpScreenBuffer, 
           DWORD PTR coordBufferSize, 
           DWORD PTR coordZero, 
           addr rectWindow
    
    ret
DrawGame endp

main proc
    invoke GetTickCount
    invoke srand, eax
    invoke GetStdHandle, STD_OUTPUT_HANDLE
    mov hStdOut, eax
    invoke SetConsoleTitleA, addr szTitle
    invoke InitBoard
    invoke SpawnPiece

    .WHILE bGameRunning != 0
        invoke Sleep, 50
        inc dwTimer
        invoke ProcessInput
        mov eax, nSpeed
        .IF dwTimer >= eax
            mov dwTimer, 0
            mov eax, nPieceY
            inc eax
            invoke CheckCollision, nPieceX, eax, nCurrentPiece, nCurrentRot
            .IF eax == 0
                inc nPieceY
            .ELSE
                invoke LockPiece
                invoke RemoveLines
                invoke SpawnPiece
            .ENDIF
        .ENDIF
        invoke DrawGame
    .ENDW
    invoke ExitProcess, 0
main endp

end main