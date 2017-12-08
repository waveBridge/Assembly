DATA SEGMENT
	FILENAME1 DB 20 DUP (0), 0, '$'                     ;文件1的位置
	FILENAME2 DB 20 DUP (0), 0, '$'                     ;文件2的位置
	HANDLE1 DW 0 										;文件1的代号
	HANDLE2 DW 0										;文件2的代号
	DTA 	DB 100 DUP (0) 								;磁盘缓冲区
	FILE1 	DB 7000 DUP ( )                             ;文件1转化为字符串
	FILE1L 	DW 0        		      					;文件1字符串长度
	FILE2 	DB 7000 DUP ( )								;文件2转化为字符串
	FILE2L	DW 0 										;文件2字符串长度
	PROMPT1 DB 0DH, 0AH, 'Open File Error. $'
	PROMPT2 DB 0DH, 0AH, 'Read File Error. $'
	PROMPT3 DB 0DH, 0AH, 'Close File Error. $'
	PROMPT4 DB 0DH, 0AH, 'Open Dir Error. $'
	PROMPT5 DB 0DH, 0AH, 'Read Dir Error. $'
	PROMPT6 DB 0DH, 0AH, 'New File Error. $'
	WAIT1	DB 0DH, 0AH, 'Please Wait... $'
	WAIT2   DB 0DH, 0AH, 'Please Input Dir: $'
	DONE1   DB 0DH, 0AH, 'Finish! $'
	FLAG	DB 1										;文件读取结束的标记
	MAXLEN	DW 0										;处理后最长文件的的长度
	TMPLEN  DW 0 										;文件比较后的长度
	MATRIX 	DW 21001 DUP (0)                            ;相似度比较使用的矩阵（用到了状态压缩,m+1行压缩为3行）
	DIRM	DB 11,0
	DIR		DB 11 DUP (0), 0,'$'						;目录地址,不超过10个字节
	FIL     DB '*.asm', 0								;文件匹配
	FILENUM	DB 0										;文件数量
	FILESET DB 300 DUP (0), 0, '$'						;文件名集合 请不要超过10个文件 每个文件名不要超过8个字节
	WHICHF1	DB 0										;外层循环记录，便于编程
	WHICHF2 DB 0										;内层
	ANSSET	DB 110 DUP (0), '$'							;最终结果
	FANS	DB 150 DUP (0), '$'							;文件的结果
	ANSSETP	DW 0										;写结果时候的指针
	OUTFILE	DB 'D:\output.txt',0			
	OUTHAND DW 0
DATA ENDS

STACK SEGMENT
	DB 50 DUP (0)
STACK ENDS

CODE SEGMENT
	ASSUME CS: CODE, DS: DATA, SS:STACK
START:	MOV AX, DATA
		MOV DS, AX 										;装载DS
		
		LEA DX, WAIT2
		MOV AH, 09H
		INT 21H 
		
		MOV AH, 0AH
		LEA DX, DIRM
		INT 21H
		
		MOV BL, DIRM+1
		MOV BH, 0
		MOV DIR[BX], 0
		
		LEA DX, WAIT1
		MOV AH, 09H
		INT 21H 										;显示"欢迎语句"
			
;***进入指定目录读取文件的文件名并保存***
		;设置磁盘缓冲区
		LEA DX, DTA
		MOV AH, 1AH
		INT 21H
		
		;进入文件所在的目录
		LEA DX, DIR
		MOV AH, 3BH
		INT 21H
		JC ERR4											;进入目录失败
		
		LEA SI, FILESET									;文件名集合的当前地址
		MOV CL, 0										;文件个数
		
		;得到第一个文件信息
		LEA DX, FIL
		MOV AH, 4EH
		INT 21H
		JC  ERR5										;读目录失败
		INC CL											;文件数量加1
		
		MOV BX, 1EH
FIRST:	MOV DL, DTA[BX]
		CMP DL, 00H
		JE  REAR
		;存入文件名集合
		MOV [SI], DL
		INC SI
		INC BX
		CMP BX, 2AH
		JBE FIRST
		
		;循环获取下一个文件的信息
REAR:	MOV BYTE PTR[SI], 0								;以空格分隔
		INC SI
		LEA DX, FIL
		MOV AH, 4FH
		INT 21H
		JC  REND										;获取文件信息完毕
		INC CL											;文件数量加1
		
		MOV BX, 1EH
REAR2:	MOV DL, DTA[BX]
		CMP DL, 00H
		JE  REAR
		MOV [SI], DL
		INC SI
		INC BX
		CMP BX, 2AH
		JBE REAR2
		JMP REAR
		
		;所有文件信息获取完毕,文件数量和文件名确定
REND:	MOV FILENUM, CL

		;MOV AH, 09H
		;LEA DX, FILESET
		;INT 21H

		JMP AFTE

;***错误或终止***
ERR4:	LEA DX, PROMPT4									;显示"打开目录错误"
		CALL DISP
		JMP EXIT

ERR5:	LEA DX, PROMPT5									;显示"读目录错误"
		CALL DISP
		JMP EXIT
		
DONE:	MOV SI, 0										;ANSSET的指针
		MOV DI, 0										;FANS的指针
		
		MOV AL, 0										;当前一行已经写的文件
		MOV AH, FILENUM				
		DEC AH											;当前一行应该写的文件
		
COPY:	MOV DL, ANSSET[SI]
		CMP DL, 00H
		JE  FONE										;当前行完成了一个
		MOV FANS[DI], DL
		INC SI
		INC DI
		JMP COPY										;不是零，存入FANS,继续扫下一个

ERR6:	LEA DX, PROMPT6									;显示“新建文件出错”
		CALL DISP
		JMP EXIT
		
FONE:	INC SI
		MOV FANS[DI], 00H
		INC DI
		MOV FANS[DI], 00H
		INC DI
		INC AL											;当前行完成数+1
		
		CMP AL, AH
		JB	COPY										;当前行还未完成
		
		MOV BL, 0DH
		MOV FANS[DI], BL
		INC DI
		MOV BL, 0AH
		MOV FANS[DI],BL
		INC DI
		
		;在这里空格
		MOV BH, FILENUM
		SUB BH, AH										;应该空多少个4格
SPACE:	MOV FANS[DI], 00H
		INC DI
		MOV FANS[DI], 00H
		INC DI
		MOV FANS[DI], 00H
		INC DI
		MOV FANS[DI], 00H
		INC DI
		MOV FANS[DI], 00H
		INC DI
		DEC BH
		CMP BH, 0
		JA	SPACE
		
		DEC AH											;下一行，该减的减
		MOV AL, 0		
		CMP AH, 0
		JA	COPY
		JMP NEWF

DONE2:	JMP DONE		
;***写文件***	
		;MOV CX, DI
		;MOV DI, 0
		;MOV AH, 02H
;FOOO:	MOV DL, FANS[DI]
		;INT 21H
		;INC DI
		;LOOP FOOO
		
		;新建文件
NEWF:	MOV AH, 3CH 
		LEA DX, OUTFILE
		XOR CX, CX										;普通文件
		INT 21H
		JC  ERR6
		MOV BX, AX
		
		MOV AH, 40H
		LEA DX, FANS
		MOV CX, DI
		INT 21H
		
		LEA DX, DONE1
		CALL DISP
	
		MOV AH, 4CH
		INT 21H

;***每次选择两个文件***
AFTE:	MOV AL, 0										;文件1的位置
CHOICE: CMP AL, FILENUM									
		JAE DONE2										;for(i=0;i<n;i++)
		MOV AH, AL										
		ADD AH, 1										;文件2的位置在文件1的后面一个
		
CHOIE1: CMP AH, FILENUM					
		JAE CHOIE2
		JMP CHOVER										;for(j=i+1;j<n;j++)
						
CHOIE2: INC AL 			
		JMP CHOICE
			
		;首先把两个文件名清空
CHOVER:	MOV CX, 20
		MOV BL, 0
		LEA SI, FILENAME1
CLEAR1:	MOV [SI], BL
		INC SI
		LOOP CLEAR1
		
		MOV CX, 20
		LEA SI, FILENAME2
CLEAR2:	MOV [SI], BL
		INC SI
		LOOP CLEAR2
			
		;先第1个文件的文件名
		MOV WHICHF1, AL									;先暂存一下文件1和2的文件位置
		MOV WHICHF2, AH
		
		MOV CL, 0										;接下来是第几个文件
		LEA SI, FILESET
		
CMPF:	CMP CL, AL										;看是否为想读的文件
		JE	YES	
CMPFF:	MOV BL,[SI]
		CMP BL, 00H
		JE  NEXTF										;下一个文件名
		INC SI 
		JMP CMPFF

NEXTF:	INC CL
		INC SI
		JMP  CMPF
		
YES:	LEA DI, FILENAME1								;准备写入文件1的名
YESS:	MOV BL, [SI]
		CMP BL, 00H
		JE  CHOVE2										;第一个写完了
		MOV [DI], BL
		INC DI
		INC SI 
		JMP YESS
		
		;该写第2个文件的文件名
CHOVE2: MOV CL, 0										;接下来是第几个文件
		LEA SI, FILESET
		
CMPF2:	CMP CL, AH										;看是否为想读的文件
		JE	YES2
CMPFF2:	MOV BL, [SI]
		CMP BL, 00H
		JE  NEXTF2										;下一个文件名
		INC SI 
		JMP CMPFF2

NEXTF2:	INC CL
		INC SI
		JMP  CMPF2
		
YES2:	LEA DI, FILENAME2								;准备写入文件2的名
YESS2:	MOV BL, [SI]
		CMP BL, 00H
		JE  CFLAG										;两个文件名均写结束
		MOV [DI], BL
		INC DI
		INC SI 
		JMP YESS2

CFLAG:	MOV AL, 1
		MOV FLAG, AL									;有两个文件需要读内容
		
		;MOV AH, 09H
		;LEA DX, FILENAME1
		;INT 21H
		;LEA DX, FILENAME2
		;INT 21H
		
		
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
		CMP DI, 7000								
		JAE CLOSE
		;MOV AH, 2
		;INT 21H
		
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
		
		XOR DX, DX
		MOV AX, SI 										;做除法，根据余数确定实际空间行号
		MOV BX, 2
		DIV BX
		CMP DX, 0 										
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
		;MOV CL, 4
		;SHR AX, CL										;AX逻辑右移4位，使得AX是AH(左边的行号)
		MOV AL, AH
		XOR AH, AH
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

		MOV DL, DH					
		XOR DH, DH										;使得DX为DH
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
		
		;求结果存放的行号(1或者2)
		XOR DX, DX
		MOV AX, FILE1L								
		MOV BX, 2
		DIV BX
		CMP DX, 0
		JE  EVEANS

ODDANS: MOV SI, 1 										;奇数行
		JMP ANS
EVEANS: MOV SI, 2										;偶数行
		
		;得到答案
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
		
		;MOV AH, 02H
		;MOV DL, AL
		;ADD DL, 30H
		;INT 21H

;***求百分比***
		MOV DI, ANSSETP
PERC:	XOR DX, DX
		MOV AX, TMPLEN							
		MOV CX, 100
		MUL CX											;相同长度先乘100,再除以最大长度
		
		MOV CX, MAXLEN
		DIV CX											;此时百分比在AX中 最大为100，所以结果其实在AL中

		CMP AX, 100
		JE HUND

		MOV BL, 10										;除以10，得到十位和个位
		DIV BL
		
		CMP AL, 0	
		JE	NOTEN
		ADD AL, 30H
		MOV ANSSET[DI], AL
		INC DI
		
		;PUSH AX
		;MOV AH, 02H
		;MOV DL, AL
		;ADD DL, 30H
		;INT 21H
		;POP AX

NOTEN: 	ADD AH, 30H
		MOV ANSSET[DI], AH
		INC DI

		;MOV DL, AH										;小于10，只打印个位
		;MOV AH, 02H
		;ADD DL, 30H
		;INT 21H																
		JMP OVER
											
HUND:	MOV ANSSET[DI], 31H
		INC DI
		MOV ANSSET[DI], 30H
		INC DI
		MOV ANSSET[DI], 30H
		INC DI

		;MOV AH, 02H									;百分之百，特殊处理直接打印100
		;MOV DL, 31H
		;INT 21H
		;MOV DL, 30H
		;INT 21H
		;MOV DL, 30H
		;INT 21H

OVER:	MOV ANSSET[DI], 37
		INC DI
		MOV ANSSET[DI], 00H
		INC DI
		MOV ANSSETP, DI
		;MOV DL, 37										;打印%
		;INT 21H
		
		MOV AL, WHICHF1
		MOV AH, WHICHF2
		INC AH
		JMP CHOIE1

;***退出***
EXIT: 	MOV AH, 4CH										;返回DOS
		INT 21H 
				
;***显示语句***
DISP:	MOV AH, 09H
		INT 21H
		RET
		
CODE ENDS
END START