@echo off

@echo // +----------------------------------------------------------------------

@echo // ^| 一键push

@echo // +----------------------------------------------------------------------

@echo // ^| 默认添加并提交当前目录下所有内容

@echo // +----------------------------------------------------------------------

@echo // ^| 另存为ANSI格式，不然会乱码

@echo // +----------------------------------------------------------------------

@echo // ^| 将源代码下面的"if"换成自己的名字

@echo // +----------------------------------------------------------------------

@echo // ^| Blog ( https://blog.csdn.net/Jay_Chou345 )

@echo // +----------------------------------------------------------------------

set filename="if于%date:~0,4%-%date:~5,2%-%date:~8,2%~%time:~0,2%:%time:~3,2%一键提交"

set "filename=%filename: =0%"

set "content=%filename%"

set "branch=master"

set /p "content=请输入提交说明(回车则默认当前时间)："

set /p "branch=请输入提交分支(回车则默认master)："

set "file=."

git add %file%

git commit -m %content%

git push origin %branch%

pause