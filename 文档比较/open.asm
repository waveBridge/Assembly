DATA SEGMENT
	FILENAME1 DB 'D:\1.asm',0                           ;文件1的位置
	FILENAME2 DB 'D:\2.asm',0                           ;文件2的位置
	HANDLE1 DW 0 										;文件1的代号
	HANDLE2 DW 0										;文件2的代号
	DTA 	DB 5 DUP ( ) 								;磁盘缓冲区
	FILE1 	DB 16384 DUP ( )                            ;文件1转化为字符串
	FILE1L 	DW 0        		      					;文件1字符串长度
	FILE2 	DB 16384 DUP ( )							;文件2转化为字符串
	FILE2L	DW 0 										;文件2字符串长度
	PROMPT1 DB 0DH, 0AH, 'Open File Error. $'
	PROMPT2 DB 0DH, 0AH, 'Read File Error. $'
	PROMPT3 DB 0DH, 0AH, 'Close File Error. $'
	FLAG	DB 1										;文件读取结束的标记
DATA ENDS

STACK SEGMENT
	DB 50 DUP (0)
STACK ENDs

CODE SEGMENT
	ASSUME CS: CODE, DS: DATA, SS:STACK
START:	MOV AX, DATA
		MOV DS, AX 										;装载DS
		
WHICH:	CMP FLAG, 1
		JNE	TWO0
ONE0:	LEA DX, FILENAME1								;文件1的操作
		MOV AH, 3DH
		MOV AL, 0 										;打开方式0,为读打开
		INT 21H 				
		JC ERR1 										;打开失败,转ERR1
		MOV HANDLE1, AX 								;保存文件代号_
		
		LEA SI, FILE1									;SI存指向FILE1的指针
		XOR DI, DI 										;放临时文件字符串长度
		JMP AGAIN
		
TWO0:	LEA DX, FILENAME2								;文件2的操作
		MOV AH, 3DH
		MOV AL, 0 										;打开方式0,为读打开
		INT 21H 				
		JC ERR1 										;打开失败,转ERR1
		MOV HANDLE2, AX 								;保存文件代号_
		
		LEA SI, FILE2									;SI存指向FILE1的指针
		XOR DI, DI 										;放临时文件字符串长度
		
		;开始读文件
AGAIN:  LEA DX, DTA										;DS: DX指向缓冲区
		CMP FLAG, 1
		JNE TWO1
ONE1:	MOV BX, HANDLE1 								;BX=文件代号
		JMP READ
TWO1:	MOV BX, HANDLE2

READ:	MOV CX, 1 										;CX=读取字节数
		MOV AH, 3FH
		INT 21H 										;从文件中读1字节,存入DTA
		JC ERR2 										;读错,转ERR2
		
		CMP AX, 0 										;读出字节数为0
		JE CLOSE 										;读出字节数为0,转CLOSE
		CMP DTA, 1AH 									;读出内容是EOF
		JE CLOSE 										;读出内容是EOF,转CLOSE
		
		;把这个字节内容存放到内存中
		MOV DL, DTA
		CMP DL, 30H
		JB  CHAR                                    	;小于‘0’，一定为符号
		CMP DL, 39H
		JBE NOCHAR										;大于等于‘0’小于等于‘9’
		CMP DL, 41H										
		JB	CHAR										;不是数字同时小于‘A’，一定是符号
		CMP DL, 5AH
		JBE NOCHAR										;大于等于‘A’，并且小于等于‘Z’
		CMP DL, 61H										
		JB	CHAR 										;不是数字和大写字母，且小于'a',那一定是符号
		CMP DL, 7AH										
		JBE NOCHAR 										;大于等于‘a’，小于等于'z'
		JMP CHAR
		
NOCHAR:	MOV [SI], DL									;放入FILE1内存中
		INC SI											;SI指针++
		INC DI											;长度++
		MOV AH, 2
		INT 21H
		
CHAR:	JMP AGAIN
		
		;错误
ERR1:   LEA DX, PROMPT1
		CALL DISP 										;显示"文件打开错误"
		JMP EXIT
		
ERR2: 	LEA DX, PROMPT2
		CALL DISP 										;显示"文件读错误"
									
CLOSE:	CMP FLAG, 1
		JNE TWO2
ONE2:	MOV FILE1L, DI 
		MOV AH, 3EH
		MOV BX, HANDLE1
		JMP CLOSE2

TWO2:	MOV FILE2L, DI 
		MOV AH, 3EH
		MOV BX, HANDLE2

CLOSE2:	INT 21H 										;关闭文件
		JC ERR3
		
		CMP FLAG, 1
		JNE EXIT	
		MOV FLAG, 0										;FALG标记清零，读取第二个文件
		JMP WHICH										
		
EXIT: 	MOV AH, 4CH										;返回DOS
		INT 21H 
		
ERR3: 	LEA DX, PROMPT3
		CALL DISP 										;显示"文件关闭错误"
		JMP EXIT
		
DISP:	MOV AH, 09H
		INT 21H
		RET
		
CODE ENDS
END START