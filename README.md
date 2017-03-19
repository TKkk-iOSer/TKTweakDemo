[TOC]
# iOS 逆向 - helloworld

##一、 前言
本篇主要制作某信的 tweak，实现在非越狱版的手机上进行 hello World 弹窗，从而熟悉 iOS 逆向相关的工具(~~不包含lldb远程调试、反汇编技术等~~)，以及了解 tweak 的主要流程(~~其实就是如何制作插件的过程~~)。

>warm：本篇只是我在操作过程中的一点总结，并不深入讲解原理。若想深入了解可以查看==iOS应用逆向工程(第2版)==或者看文章最后的参考文档。

* 基本原理： 通过 app 启动时调用我们注入的动态库，从而进行 hook 。而之所以能够执行我们注入的动态库，是因为使用了`mobilesubstrate` 这个库，这个库能在程序运行的时候动态加载我们注入动态库。而非越狱手机里面是没有的，所以我们需要直接将这个库打包进 ipa 中，使用它的 API 实现注入。`mobilesubstrate` 库在下面的 github 中有提供，即是`libsubstrate.dylib`.

* 本demo的github地址 : [TKDemo](https://github.com/tusiji7/TKTweakDemo.git)
  其中 /others 提供了 `libsubstrate.dylib` 与 本人写的 `autoInsertDylib.sh`脚本，`autoInsertDylib.sh`是用来实现注入动态库一体化。

* **以下部分工具(~~例如 claa-dump 、insert_dylib~~)可使用Xcode进行编译(command + b)，然后在工程目录下的Products中拷贝目标文件，放在 `/usr/local/bin` 目录中,方便在 Termimal 中使用。**

* *主要流程： 砸壳 ==> 获取ipa ==> 制作tweak ==> 查看(更改)依赖库 ==> 注入动态库 ==> 打包重签名 ==> 安装*

---
##二、 正文
###1. SSH  服务
> 实现在越狱手机上远程进行ssh服务

OpenSSH 在 Cydia 中安装 OpenSSH

* ssh : 远程登录

```
// 指令 ssh user@iOSIP
$ ssh mobile@192.168.1.6
```
* scp : 远程拷贝   
本地文件拷贝到iOS上(iOS拷贝到本地则相反)

```
// 指令 scp /path/to/localFile user@iOSIP:/path/to/remoteFile
scp ~/Desktop/1.png root@192.168.1.6:/var/tmp/
```

**注意，OpenSSH 默认登录密码为 ==alpine== ，iOS 上的用户只有 root 与 mobile，修改密码使用`passwd root（mobile）`**

----
###2. 砸壳
> 用来在越狱手机上获取ipa

==PS:可直接使用[PP助手](http://pro.25pp.com/pp_mac_ios)下载越狱版本的 ipa 文件(~~我就是这么懒得~~)==

[Cluth](https://github.com/KJCracks/Clutch)

* 下载并得到执行文件

```
$ git clone https://github.com/KJCracks/Clutch
$ cd Clutch
// 使用 Xcode 进行build，得到可执行文件
$ xcodebuild -project Clutch.xcodeproj -configuration Release ARCHS="armv7 armv7s arm64" build
```
* 将可执行文件通过 ssh 拷贝到手机

```
scp Clutch/clutch root@<your.device.ip>:/usr/bin/
```
* 先 ssh 到越狱手机上，`clutch -i`列出当前安装的应用,再使用`clutch -d 序列号(或者bundle id)`进行砸壳

```
$ ssh root@<your.device.ip>
$ clutch -i // 列出当前安装的应用
$ clutch -d bundle id (序列号) // 砸壳
```

clutch 将砸过后的 ipa 文件放到了`/private/var/mobile/Documents/Dumped/`

* 拷贝到桌面

```
$ scp root@<your.device.ip>:/private/var/mobile/Documents/Dumped/xx.ipa ~/Desktop
```
---
###3. 导头文件（查看 app 相关头文件的信息）
>dump 目标对象的 class 信息的工具。

[class-dump](http://stevenygard.com/projects/class-dump/)

将 demo.app 的头文件导出到`~/Document/headers/`中

```
class-dump -S -s -H demo.app -o ~/Document/headers/
```

---
###4. 制作 dylib 动态库
> 制作我们要注入的 dylib 动态库   

本文章使用的是 [theos](https://github.com/theos/theos)

PS:也可以使用[iOSOpenDev](http://iosopendev.com/)
>iOSOpenDev 集成在 Xcode 中，提供了一些模板，可直接使用 Xcode 进行开发。只是这个工具停止更新，对高版本的 Xcode 不能很好地支持。本人装了多次老是失败，虽然最后在 Xcode 中有看到该工具，也不确定是否安装成功。若装失败可参考[iOSOpenDev Wiki](https://github.com/kokoabim/iOSOpenDev/wiki)

####4.1 安装并配置 theos
从 github 下载至`opt/theos/`

```
brew install dpkg ldid

export THEOS=/opt/theos
sudo git clone --recursive https://github.com/theos/theos.git $THEOS
sudo chown -R $(id -u):$(id -g) /opt/theos
```

可==配置环境变量==,`vi ~/.bash_profile`,在 ==.bash_profile== 文件的最后加入(~~否则每次重启Terminal都要重新export~~)

```
export PATH=/opt/theos/bin:$PATH
export THEOS=/opt/theos
```
####4.2 创建tweak
使用 `nic.pl` 创建 tweak
~~若提示无此命令请根据上一步骤配置环境变量，或者不嫌麻烦使用`/opt/theos/bin/nic.pl`~~
根据提示选择 ==iphone/tweak==，接着分别输入

* 项目名
* 该 deb 包的名字（~~类似 bundle identifier, 此 bundle identifier 与要 hook 的 app 的 bundle identifier 不是同一个~~）
* 作者
* tweak 作用对象的 bundle identifier（~~比如某信为com.tencent.xin~~）
* tweak 安装完成后需要重启的应用名。（~~比如某信为WeChat~~）

如下所示：

![创建 tweak.png](http://upload-images.jianshu.io/upload_images/965383-adef5e264d5bad8d.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


完成后会看到四个文件(~~make 后将生成 .theos 、obj 文件夹~~).
`Makefile          TKDemo.plist  Tweak.xm          control`

* ==Makefile== : 工程用到的文件、框架、库等信息。
该文件过于简单，还需要添加一些信息。如
指定处理器架构`ARCHS = armv7 arm64`
指定SDK版本`TARGET = iphone:latest:8.0`
导入所需的framework等等。   
修改后的Makefile文件如下所示：
![Makefile modified.png](http://upload-images.jianshu.io/upload_images/965383-ce48a5803e5e6c33.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


* ==TKDemo.plist== 该文件中的 Bundles : 指定 bundle 为 tweak 的作用对象。也可添加多个 bundle, 指定多个为 tweak 作用对象。   
![plist.png](http://upload-images.jianshu.io/upload_images/965383-4031611bc6710a9c.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)


* ==control== ： 该 tweak 所需的基本信息 (~~其实大部分都是刚刚创建 tweak 所填写的信息啦~~)
![control.png](http://upload-images.jianshu.io/upload_images/965383-503cc428e16ac218.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)



* ==Tweak.xm== ：重点文件，用来编写 hook 代码,因为支持`Logos`和`C/C++`语法，可以让我们不用去写一些 runtime 方法(~~必要时候还是要写~~)从而进行 hook 。
> .x 文件支持Logos语法，.xm 文件支持Logos和C/C++语法。

####4.3 Logos 常用语法
* `%hook`   
    指定需要 hook 的类，以`%end`结尾。
* `%orig`   
    在 `%hook` 内部使用，执行 hook 住的方法原代码。
* `%new`   
     在`%hook`的内部使用，给 class 添加新方法，与`class_addMethod`相同。   
     与 Category 中添加方法的区别：Category 为编译时添加，`class_addMethod` 为动态添加。   
**warm ：添加的方法需要在 @interface 中进行声明**
* `%c`   
获取一个类，等同于`objc_getClass`、`NSClassFromString`  

> `%hook`、`%log`、`%orig` 等都是 `mobilesubstrate` 的 `MobileHooker` 模块提供的宏，除此之外还有 `%group` `%init`、 `%ctor`等,其实也就是把 `method swizzling` 相关的方法封装成了各种宏标记，若想深入了解，请左转 [Google](www.google.com)       

####4.4 编写 tweak.xm
熟悉各种语法之后便可以进行编写代码了，其中`MMUIViewController`为某信的基础的ViewController。我们通过 hook `viewDidApper:` 来进行 hello World 弹窗。
![tweak.xm.png](http://upload-images.jianshu.io/upload_images/965383-2a245ca9f43e31b5.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

####4.5 编译
使用`make`进行编译
若想重新编译记得先`make clean`(~~感谢我的嵌入式老师，让我还记得这个~~)
`make`后在当前文件夹下面将生成两个文件夹:`.theos` 与 `obj`,其中我们编译完成的动态库就在`.thoes/obj/debug`的下面，与工程名相同。

**若编译的时候提示找不到 `common.mk` 或者是 `tweak.mk`，请根据上述步骤（==4.1 安装并配置 theos==）重新 export theos，或写入至~/.bash_profile，或更改Makefile的文件，将`$(THEOS)/makefiles` 与 `$(THEOS_MAKE_PATH)` 替换成`opt/theos/makefiles`**
![make.png](http://upload-images.jianshu.io/upload_images/965383-301fc12dbaa0e8c7.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

---
###5. 查看（修改）依赖
####5.1 otool
> 查看执行文件所依赖的库文件

```
otool -L TKDemo.dylib
```

![查看依赖库.png](http://upload-images.jianshu.io/upload_images/965383-cdca48c290f3ace2.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

若发现有依赖 `/Library/Frameworks/CydiaSubstrate.framework/CydiaSubstrate` 使用 install_name_tool 更改依赖。

>CydiaSubstrate 只有越狱的手机上才有，因此需要我们手动更改并导入。

---
####5.2 更换动态库的依赖

```
install_name_tool -change /Library/Frameworks/CydiaSubstrate.framework/CydiaSubstrate @loader_path/libsubstrate.dylib tkchat.dylib  
// install_name_tool -change 需要替换的库 @loader_path/需要引用的库 需要更改的dylib
```

![替换依赖库.png](http://upload-images.jianshu.io/upload_images/965383-9a133bce9c59b562.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

---

###6. 动态库注入
>把我们写的动态库注入到要 hook 的二进制文件

[insert_dylib](https://github.com/gengjf/insert_dylib)


**先将 ipa 文件解压，在解压后的`/Payload`目录中，将app可执行文件拷贝出来。再将我们编写的动态库与libsubstrate.dylib 拷贝至app的包内容中。**
执行命令：
`./insert_dylib 动态库路径 目标二进制文件`

```
 ./insert_dylib @executable_path/xxxx.dylib xxxx
 // @executable_path 是一个环境变量，指的是二进制文件所在的路径
```

![注入动态库.png](http://upload-images.jianshu.io/upload_images/965383-4269d4c6241ec0f2.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)
~~之所以能够不使用./是因为已经将 insert_dylib 导入到/usr/local/bin目录中~~
**warm ：使用 insert_dylib 时若出现 error 记得修改权限， `chmod 777 insert_dylib`**

---
###7. 打包、重签名、安装
使用图形化打包签名工具 [ios-app-signer](https://github.com/DanTheMan827/ios-app-signer)
> 选择相应的证书与 Provisioning Profile 文件进行打包。

![打包重签名.png](http://upload-images.jianshu.io/upload_images/965383-ec0313e0def01dc3.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

~~友情提示：如果证书没有支持 watch，请删除 app 中的==watch==相关的文件。~~

证书的话可以用 Xcode 新建个 Project (~~个人开发者证书7天后过期~~)，在手机上运行下即可生成。导入时记得到真机上需要有相应的Provisioning Profile 文件。可在 Xcode-Window-Devices，双指点击设备查看Provisioning Profile文件，点击下面的 `+` 进行安装。

![Devices.png](http://upload-images.jianshu.io/upload_images/965383-779ee64170495e9c.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

也可使用[PP助手](http://pro.25pp.com/pp_mac_ios)进行安装。

---
###8. hello World
> 最后就是我们的 hello World

![hello World.png](http://upload-images.jianshu.io/upload_images/965383-30bee467e5ec526d.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

---
###9. autoInsertDylib.sh 脚本
>由于以上的操作(查看更改依赖库、注入动态库)都类似且繁琐，个人懒癌，就写了这个sh。

==warm !!!==
==warm !!!==
==warm !!!==
==该脚本的中`insert_dylib`路径使用的是`/usr/local/bin`(~~请看前言~~),请根据自身环境更改脚本中的`insert_dylib`路径，以免错误。==

==`iOS App Singer` 本人放在了`/Applications/`中，若Applications中没有，则在脚本执行完手动打开==

使用：

```
 ./autoInsertDylib.sh ipa路径 libsubstrate.dylib路径 要注入的dylib路径
```

![autoInsertDylib 操作.png](http://upload-images.jianshu.io/upload_images/965383-bacd4d58b44432e3.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

autoInsertDylib.sh 内容

```shell
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

```

---
##三、 总结
以上就是整个 iOS 逆向的主要流程(~~虽然hook的代码很渣~~),其中注入动态库与打包重签名的工具不止一种，可以根据自己的爱好网上查找。本人也是踩了不少坑不断摸索来的，比如由于tweak工程名的问题，导致使用 `iOS App Signer` 打包重签名的一直error：==Error verifying code signature==。希望能给刚入iOS 逆向坑的人一点帮助。由于涉及只是工具的使用，涉及到的原理比较薄弱，希望各位可以去阅读下参考文档。

---
##四、参考文档

[iOS应用逆向工程 第2版](https://book.douban.com/subject/26363333/)

[移动App入侵与逆向破解技术－iOS篇](http://mp.weixin.qq.com/s?__biz=MzA3NTYzODYzMg==&mid=2653577384&idx=1&sn=b44a9c9651bf09c5bea7e0337031c53c&scene=0#wechat_redirect)

[Make WeChat Great Again](http://yulingtianxia.com/blog/2017/02/28/Make-WeChat-Great-Again/)

[如何在逆向工程中 Hook 得更准 - 微信屏蔽好友&群消息实战](http://yulingtianxia.com/blog/2017/03/06/How-to-hook-the-correct-method-in-reverse-engineering/)

[让你的微信不再被人撤回消息](http://yulingtianxia.com/blog/2016/05/06/Let-your-WeChat-for-Mac-never-revoke-messages/)

[免越狱版 iOS 插件](http://www.swiftyper.com/2016/12/26/wechat-redenvelop-tweak-for-non-jailbroken-iphone/)
