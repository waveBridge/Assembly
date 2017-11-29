DATA SEGMENT
	FILENAME1 DB 'ON.ASM',0,0,0
	DIR		DB 'D:\CODE', 0								;目录地址
	FIL     DB '*.asm', 0								;文件匹配
	FILENUM	DB 10										;文件数量
	PROMPT1 DB 0DH, 0AH, 'Open File Error. $'
	PROMPT2 DB 0DH, 0AH, 'Read File Error. $'
	PROMPT3 DB 0DH, 0AH, 'Close File Error. $'
	PROMPT4 DB 0DH, 0AH, 'Open Dir Error. $'
	PROMPT5 DB 0DH, 0AH, 'Read Dir Error. $'
	PROMPT6	DB 0DH, 0AH, 'New File Error. $'
	WAIT1	DB 0DH, 0AH, 'Please Wait... $'
	FILESET DB 500 DUP (0),'$'							;文件名集合	不超过50个文件
	DTA 	DB 100 DUP(0) 								;磁盘缓冲区
	ANSSET 	DB '100%25%0%85%45%100%25%0%85%45%' 		;结果集
	OUTF	DB 'D:\output.txt',0			
	OUTHAND DW 0										;新文件文件号
	SPACE  DB 5 DUP (0)
	
DATA ENDS

STACK SEGMENT
	DB 50 DUP (0)
STACK ENDs

CODE SEGMENT
	ASSUME DS:DATA, CS:CODE, SS:STACK
START:	MOV AX, DATA
		MOV DS, AX
		
		MOV AH, 3CH
		XOR CX, CX						;普通文件
		LEA DX, OUTF
		INT 21H							;新建文件
		JC  ERR6						;新建失败
		MOV OUTHAND, AX					;文件号
		
		MOV AH, 40H
		MOV SI, 0						;缓冲区的第几个位置
		MOV DI, 1 						;打空格了没
		
SPAC:	CMP DI, 0
		JE	PUT							;空格打完了
		LEA DX, SPACE
		MOV BX, OUTHAND
		MOV CX, 2
		INT 21H
		MOV DI, 0 
		JMP SPAC
		
PUT:	PUSH SI
		MOV  CX, 1						;CX是这个百分数的位数
IS37：	CMP ANSSET[SI], 37
		JE	PUT2
		INC CX
		INC SI
		JMP IS37
		
PUT2：	POP SI
		MOV AH, 40H
		MOV BX, OUTHAND
		LEA DX, SPACE
		ADD DX, SI
		INT 21H
		
		ADD SI, CX
		MOV DI, 1
		JMP 
		
		
		
		
ERR6:	LEA DX, PROMPT6
		CALL DISP
		JMP EXIT
		
EXIT:	MOV AH, 4CH
		INT 21H
		
DISP:	MOV AH, 09H
		INT 21H
		RET

CODE ENDS
END START