DATA SEGMENT
	FILENAME1 DB 'D:\1.asm',0                           ;文件1的位置
	FILENAME2 DB 'D:\2.asm',0                           ;文件2的位置
	HANDLE1 DW 0 										;文件1的代号
	HANDLE2 DW 0										;文件2的代号
	DTA 	DB 5 DUP ( ) 								;磁盘缓冲区
	FILE1 	DB 8000 DUP ( )                             ;文件1转化为字符串
	FILE1L 	DW 0        		      					;文件1字符串长度
	FILE2 	DB 8000 DUP ( )								;文件2转化为字符串
	FILE2L	DW 0 										;文件2字符串长度
	PROMPT1 DB 0DH, 0AH, 'Open File Error. $'
	PROMPT2 DB 0DH, 0AH, 'Read File Error. $'
	PROMPT3 DB 0DH, 0AH, 'Close File Error. $'
	FLAG	DB 1										;文件读取结束的标记
	MAXLEN	DW 0										;处理后最长文件的的长度
	TMPLEN  DW 0 										;文件比较后的长度
	MATRIX 	DW 24001 DUP (0)                            ;相似度比较使用的矩阵（用到了状态压缩,m+1行压缩为3行）
DATA ENDS

STACK SEGMENT
	DB 50 DUP (0)
STACK ENDs

CODE SEGMENT
	ASSUME CS: CODE, DS: DATA, SS:STACK
START:	MOV AX, DATA
		MOV DS, AX 										;装载DS
		
;***选择哪一个文件做操作***
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
		JMP INIT
		
TWO0:	LEA DX, FILENAME2								;文件2的操作
		MOV AH, 3DH
		MOV AL, 0 										;打开方式0,为读打开
		INT 21H 				
		JC ERR1 										;打开失败,转ERR1
		MOV HANDLE2, AX 								;保存文件代号_
		
		LEA SI, FILE2									;SI存指向FILE1的指针
		XOR DI, DI 										;放临时文件字符串长度
		
;***开始读文件，预处理并放入内存***
INIT:   LEA DX, DTA										;DS: DX指向缓冲区
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
		JE 	CLOSE 										;读出字节数为0,转CLOSE
		CMP DTA, 1AH 									;读出内容是EOF
		JE 	CLOSE 										;读出内容是EOF,转CLOSE
		
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

;***错误***
ERR1:   LEA DX, PROMPT1
		CALL DISP 										;显示"文件打开错误"
		JMP EXIT

ERR2: 	LEA DX, PROMPT2
		CALL DISP 										;显示"文件读错误"
		JMP EXIT

ERR3: 	LEA DX, PROMPT3
		CALL DISP 										;显示"文件关闭错误"
		JMP EXIT
		
NOCHAR:	MOV [SI], DL									;放入FILE1内存中
		INC SI											;SI指针++
		INC DI											;长度++
		CMP DI, 8000								
		JAE CLOSE
		MOV AH, 2
		INT 21H
		
CHAR:	JMP INIT
		

;***读文件完毕，关闭文件，求长度***								
CLOSE:	CMP FLAG, 1
		JNE TWO2
ONE2:	MOV FILE1L, DI 									;文件1的长度存到FILE1L
		MOV AH, 3EH
		MOV BX, HANDLE1
		JMP CLOSE2

TWO2:	MOV FILE2L, DI 									;文件2的长度存到FILE2L
		MOV AH, 3EH
		MOV BX, HANDLE2

CLOSE2:	INT 21H 										;关闭文件
		JC  ERR3
		
		CMP FLAG, 1
		JNE MAXL	
		MOV FLAG, 0										;FALG标记清零，读取第二个文件
		JMP WHICH										

;***求处理后文件的最大长度***
MAXL:	MOV BX, FILE1L
		MOV CX, FILE2L 
		CMP BX, CX		
		JBE BIGL
		MOV DX, FILE1L
		MOV MAXLEN, DX
		JMP SAME

BIGL:	MOV DX, FILE2L
		MOV MAXLEN, DX
		

;***相似度计算***
SAME:	MOV SI, 1 										;文件1的指针
		MOV DI, 1 										;文件2的指针
		
FOR1:	CMP SI, 1
		JE  FLINE 										;第一特行殊处理
		
		MOV AX, SI 										;做除法，根据余数确定实际空间行号
		MOV DL, 2
		DIV DL
		CMP AH, 0 										
		JZ 	EVENN

		;寄存器的值对应的意义：AH->left(左边的行号)	AL->up(上边的行号)	DH->leftUp(左上方的行号)	DL->ii(当前行号)
ODDN:	MOV AH, 1										;奇数行，对应到实际空间为第1行
		MOV DH, 2
		MOV AL, 2
		MOV DL, 1
		JMP DP 

EVENN:	MOV AH, 2										;偶数行，对应到实际空间为第2行
		MOV DH, 1
		MOV AL, 1
		MOV DL, 2
		JMP DP
		
FLINE:	MOV AH, 1
		MOV DH, 0
		MOV AL, 0
		MOV DL, 1
		
DP:		LEA BX, FILE1
		DEC BX
		MOV CH, [BX + SI] 							;BX减了一下，实际为[BX + SI - 1]
		LEA BX, FILE2
		DEC BX
		MOV CL, [BX + DI]								;BX减了一下，实际为[BX + DI - 1]
		
		CMP CH, CL
		JE	LEFTUP
		
		;当前字符不等，那么为左边或者上边
		;算左边
		PUSH DX
		PUSH AX 
		MOV CL, 4
		SHR AX, CL										;AX逻辑右移4位，使得AX是AH(左边的行号)
		MOV CX, FILE2L
		INC CX 											;每一行的长度是文件2的长度+1
		MUL CX 
		MOV BX, AX
		
		ADD BX, DI
		DEC BX
		ADD BX, BX
		MOV DX, MATRIX[BX]   	 						;BX减了一下，实际为[(BX + DI - 1)*2],左方数据
		
		;算上边
		POP AX
		PUSH DX											;存入左方数据
		XOR AH, AH										;AX高四位置零，使得AX为AL(上方行号)
		MUL CX
		MOV BX, AX
		ADD BX, DI
		ADD BX, BX
		MOV CX, MATRIX[BX]								;上方数据([(BX + DI)*2])
		POP DX											;取出左方数据

		CMP DX, CX
		JA MAXN
		JMP THEMAX 
		
FOR2:	JMP FOR1
		
MAXN:	MOV CX, DX										;上边更大
		
		;当前位置放入更大的数
THEMAX:	POP DX
		PUSH CX
		XOR DH, DH										;取得当前行
		MOV AX, DX
		MOV CX, FILE2L
		INC CX
		MUL CX 
		MOV BX, AX
		ADD BX, DI
		ADD BX, BX
		POP CX
		MOV MATRIX[BX], CX 
		JMP NEXT
		
		;左上方
LEFTUP:	PUSH DX
;;;;;;;;;;;卧槽这么玄学的吗？？？！！！位移就不行
		PUSH AX
		PUSH DX
		MOV AH, 02H
		MOV DL, DH
		ADD DL, 30H
		INT 21H
		POP DX
		POP AX
;;;;;;;;;;		
		MOV CL, 4										
		SHR DX, CL										;DX逻辑右移4位，使得DX位原先的DH值
;;;;;;;;;		
		;PUSH AX
		;PUSH DX
		;MOV AH, 02H
		;ADD DL, 30H
		;INT 21H
		;POP DX
		;POP AX
;;;;;;;;;;;		
		MOV AX, DX 										
		MOV CX, FILE2L    				
		INC CX											;一行的个数是文件2的长度+1
		MUL CX 											;AX中的行号乘以CX中的每行的元素个数 结果在AX中
		MOV BX, AX										;结果存入基址寄存器BX
		ADD BX, DI
		DEC BX 
		ADD BX, BX
		MOV CX, MATRIX[BX]                    		    ;BX减了，实际为[(BX + DI - 1)*2]
		INC CX											;此时CX是matrix[leftUp][j - 1] + 1
		
		MOV AH, 02H
		MOV DX, CX 
		INT 21H
		;MOV DX, BX
		;INT 21H
		;MOV DL, 16
		;INT 21H
		
		POP DX
		PUSH CX
		XOR DH, DH 										;DX高4位置零，使得结果为DL，当前行号
		MOV AX, DX
		MOV CX, FILE2L    				
		INC CX											;一行的个数是文件2的长度+1
		MUL CX 											;AX中的行号乘以CX中的每行的元素个数 结果在AX中										
		MOV BX, AX										;计算的是当前行对应的结果
		ADD BX, DI
		ADD BX, BX
		POP CX
		MOV MATRIX[BX], CX
		
		;MOV AH, 02H
		;MOV DX, BX
		;INT 21H
		;MOV DL, 30
		;INT 21H
		
		JMP NEXT
		
NEXT:	INC DI 
		MOV AX, FILE2L
		CMP DI, AX
		JBE FOR2
		MOV DI, 1
		INC SI 
		MOV AX, FILE1L
		CMP SI, AX
		JBE FOR2
		
		;得到答案
		MOV AX, FILE1L									;求最后的长度
		MOV BL, 2
		DIV BL
		CMP AH, 0
		JE  EVEANS

ODDANS: MOV SI, 1 										;奇数行
		JMP ANS
EVEANS: MOV SI, 2										;偶数行

ANS:	MOV DI, FILE2L
		MOV AX, SI
		MOV CX, FILE2L
		INC CX
		MUL CX 
		MOV BX, AX
		ADD BX, DI
		ADD BX, BX
		MOV AX, MATRIX[BX]
		MOV TMPLEN, AX
		
		MOV AH, 02H
		;MOV DL, AL
		;INT 21H
		
		MOV DL, 39H
		INT 21H
		JMP EXIT
		

;***退出***
EXIT: 	MOV AH, 4CH										;返回DOS
		INT 21H 
				
;***显示语句***
DISP:	MOV AH, 09H
		INT 21H
		RET
		
CODE ENDS
END START