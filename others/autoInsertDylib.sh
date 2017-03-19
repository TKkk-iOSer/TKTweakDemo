# !/bin/bash

SOURCEIPA="$1"
LIBSUBSTRATE="$2"
DYLIB="$3"

if [ ! -d ~/Desktop/tk-tweak-temp-folder/ ]; then
	echo "在 Desktop 创建tk-tweak-temp-folder"
	mkdir ~/Desktop/tk-tweak-temp-folder

else
	rm -rf ~/Desktop/tk-tweak-temp-folder/*
fi

cp "$SOURCEIPA" "$DYLIB" "$LIBSUBSTRATE" ~/Desktop/tk-tweak-temp-folder/

echo "正将" ${SOURCEIPA##*/} ${DYLIB##*/} ${LIBSUBSTRATE##*/}  "拷贝至~/Desktop/tk-tweak-temp-folder"

cd ~/Desktop/tk-tweak-temp-folder/


otool -L ${DYLIB##*/} > depend.log
grep "/Library/Frameworks/CydiaSubstrate.framework/CydiaSubstrate" depend.log >grep_result.log
if [ $? -eq 0 ]; then
    echo "发现有依赖于 CydiaSubstrate, 正将其替换为 libsubstrate"
	install_name_tool -change /Library/Frameworks/CydiaSubstrate.framework/CydiaSubstrate @loader_path/libsubstrate.dylib ${DYLIB##*/}

else
    echo "没有发现依赖于CydiaSubstrate"
fi

echo "解压" ${SOURCEIPA##*/}

unzip -qo "$SOURCEIPA" -d extracted

APPLICATION=$(ls extracted/Payload/)

cp -R ~/Desktop/tk-tweak-temp-folder/extracted/Payload/$APPLICATION ~/Desktop/tk-tweak-temp-folder/

echo "注入" ${DYLIB##*/} "到" $APPLICATION
cp ${DYLIB##*/} ${LIBSUBSTRATE##*/} $APPLICATION/

echo "删除" ${APPLICATION##*/} "中 watch 相关文件"

rm -rf ~/Desktop/tk-tweak-temp-folder/$APPLICATION/*watch*
rm -rf ~/Desktop/tk-tweak-temp-folder/$APPLICATION/*Watch*


echo "是否注入" ${DYLIB##*/} ":(Y/N)"

insert_dylib  @executable_path/${DYLIB##*/} $APPLICATION/${APPLICATION%.*} > insert_dylib.log

echo "注入成功"
cd $APPLICATION

rm -rf ${APPLICATION%.*}
mv ${APPLICATION%.*}_patched ${APPLICATION%.*}

echo "正将"  ${APPLICATION%.*}_patched "覆盖为" ${APPLICATION%.*}

cd ~/Desktop/tk-tweak-temp-folder/

echo "删除临时文件"

rm -rf ${SOURCEIPA##*/} ${DYLIB##*/} ${LIBSUBSTRATE##*/} extracted insert_dylib.log depend.log grep_result.log

echo "打开 tk-tweak-temp-folder 文件夹"
open ~/Desktop/tk-tweak-temp-folder
open /Applications/iOS\ App\ Signer.app
