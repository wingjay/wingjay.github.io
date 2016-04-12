title: 30条Android开发建议
date: 2016-03-15 12:03:03
tags: 
	- Android
---
![](https://cdn-images-1.medium.com/max/2000/1*4kl1dDdzNf6hMHdnOQzd7w.jpeg)

    There are two kinds of people ：
     those who learn the hard way and those who learn by taking someone’s advice. 

<!-- more -->

本文主要用来收集Android开发中积累的一些宝贵经验，这些经验中有一些约定熟成且经过检验的建议，有一些结合最新技术的实践。无论是菜鸟还是大神，都应该学会阅读别人的经验，并结合自己的思考转化成对自己有用的知识，这才是最快的成长之路。另外，对于这些建议，我会尽量翔实的进行说明以确保能够顺利快速应用到实际开发中。

## 介绍
下面以这篇文章：[Building Android Apps — 30 things that experience made me learn the hard way](https://medium.com/@cesarmcferreira/building-android-apps-30-things-that-experience-made-me-learn-the-hard-way-313680430bf9#.efowqynql)为核心，对其中提出的每一点建议进行较为深入的分析探究，最终整理成一篇完整的文章。当然，本文还在不断更新中。

#### 第三方库 
在你添加每一个third party library之前，请认真考虑是否真的需要这个library。
#### OverDraw
如果用户看不到，那就不要进行绘制(draw)，或者说，不要`过度绘制 OverDraw`
`OverDraw`会导致GPU浪费，也会导致app的速度变慢。为了减少这种危害，我们可以利用[`Debug GPU Overdraw Tool`](http://developer.android.com/tools/performance/debug-gpu-overdraw/index.html)来观察app里的绘制情况，然后可以使用[Hierarchy Viewer](http://developer.android.com/tools/performance/hierarchy-viewer/index.html)来进行优化。 
#### 数据库
除非不得不，否则不要使用`database`
#### 65k methods limit
`Dalvik 65K methods limit`你很快就会遇到的，不过放心，[`multidexing`](https://medium.com/@rotxed/dex-skys-the-limit-no-65k-methods-is-28e6cb40cf71)会帮助你。
什么是`Dalvik 65K methods limit`？我们知道，我们写完java code之后，dx tool会把java编译成Dalivik虚拟机能识别的`DEX`文件，这个文件里最多能够索引`65536个method`。关于这个有两点要注意：
1. 这些method是指能够`索引(reference)`到的，而不是`定义(define)`的。或者说，如果你定义了一个方法，但这个方法并没有被调用，那么就不算在内。
2. 这些method不仅仅是开发人员自己写的，还包括所有第三方library里面的method。

所以，我们总共可以索引`65536`个方法，包括自己写的和引入第三方库里的。
那么，我们如何能快速知道我们的app里已经有多少个method了呢？    
- bash script: [dex-method-counts](https://github.com/mihaip/dex-method-counts)。这个工具可以快速计算，并且提供一个清晰的视图来阅读。
- [dex.sh](https://gist.github.com/JakeWharton/6002797) by Jake Wharton。这个工具由于采用了递归算法，所以耗时比较长。(Jake大神还写了一篇有趣的分析文章[Play Services 5.0 Is A Monolith Abomination](http://jakewharton.com/play-services-is-a-monolith/)，针对Play Services 5.0太大的问题进行了分析，有空时我再翻译下给各位。虽然[Play Services 6.5已经模块化，更加轻量级了](http://android-developers.blogspot.it/2014/12/google-play-services-and-dex-method.html)）。
     
现在，既然我们已经知道了自家app里的method数了，那么如何来处理这种情况呢？
- [Multidex](http://developer.android.com/tools/building/multidex.html)，官方提供的解决方案，[这篇文章](http://blog.osom.info/2014/10/multi-dex-to-rescue-from-infamous-65536.html)里有详细的使用方法，此不赘述。
- [ProGuard](http://developer.android.com/tools/help/proguard.html)
`ProGuard`可以把code里unnecessary的method移除，压缩apk，当然还有`代码混淆`的奇效。
- 再创建一个`DEX File`。把app里可以独立的模块或code提取出来，放到一个独立的dex文件里，你可以使用[Custom ClassLoader](http://android-developers.blogspot.it/2011/07/custom-class-loading-in-dalvik.html)来加载这些类，然后使用`接口`或`反射`来调用这些方法。不过，这个过程还是比较麻烦的。

#### `RxJava, RxAndroid & Retrolambda`
使用前可以通过[这篇gist](https://gist.github.com/cesarferreira/510aa2456dc0879f559f#file-rxjava-md)来了解[RxJava](https://github.com/ReactiveX/RxJava)＋[RxAndroid](https://github.com/ReactiveX/RxAndroid)＋[Retrolambda](https://github.com/orfjackal/retrolambda)的结合用法。这个组合可以优雅的在不同线程中处理事务，同时能够方便的实现数据流动和及时响应，而且Retrolambda能够精简你的code。其中，核心的两个概念是`Observables`和`Subscribers`，前者对外提供数据，后者监听并消费这些数据。
另外，这里有一个看起来不错的项目[Learning RxJava for Android by example](https://github.com/kaushikgopal/RxJava-Android-Samples)，等空闲时再去阅读下code。

#### `Retrofit` ＋ RxJava
利用[Retrofit](http://square.github.io/retrofit/)与RxJava结合，为你的app提供网络请求服务。
你可以参考这个[超赞的例子](https://gist.github.com/cesarferreira/da1e8fc5742ab1e581b7)，让你快速感受二者结合使用方法。

#### 按`feature`来分package，而不是按`layer`
这是这篇文章提出的一个点，文中认为分package就像公司安排座位，要按照`team`来分而不是按照每个人的职位来分，即按照负责一个app的`developer、designer、pm`坐在一起，而不是把所有`developer`坐在一起，所有`designer`坐在一起。所以，原文作者认为把一个feature相关的如`Activity ` `adapter`等都放在一起。

不过，我认为按feature也有坏处，那就是`复用`，拿adapter来讲，一个app里很多adapter是类似且可以复用的，如果我们把各个adapter拆倒各个角落里，就很难提取其中的关联来创建一个`BaseAdapter`了。而且，`不同feature之间也有很多公用的东西`，比如一个自定义view，那就很难界定应该放在哪个feature包里了。相反，我们把所有自定义view放在一起，这样也有助于我们发现某些自定义view的区别，然后在refactor时可以提取公用的东西来`复用`。

关于这点，欢迎读者给出自己意见。

#### Gradle 加速
参考[这篇文章](https://medium.com/the-engineering-team/speeding-up-gradle-builds-619c442113cb#.vpoaqdivn)来加速你的Gradle

#### 架构：使用clean Architecture
这里有两篇优质文章:[Architecting Android…The clean way?](http://fernandocejas.com/2014/09/03/architecting-android-the-clean-way/)和[Architecting Android…The evolution](http://fernandocejas.com/2015/07/18/architecting-android-the-evolution/) 分别介绍并用code实现了一个Clean架构。后面我也会专门分析下这种架构，因为对于任何一个project而言，最初的好的架构是非常重要的！所以，如果你想提高自己，那么`架构`这一关是必经之路。

#### 测试你的app
虽然做测试需要花费你不少时间，但一旦你完成了这一步，以后的开发会更加快速，app也会更加稳定。
这里有个哥们，[对`unit test`进行了细致的点评](http://stackoverflow.com/a/67500/794485)。

#### 使用`依赖注入`神器`Dagger`
如果你不知道什么是`依赖注入`，你可以先读一下这篇文章[Dependency injection on Android: Dagger (Part 1)](http://antonioleiva.com/dependency-injection-android-dagger-part-1/)，或者这篇[依赖注入](https://github.com/android-cn/blog/tree/master/java/dependency-injection)。简单来说，依赖注入替代了传统创建对象的`new`操作，当需要创建一个class的实例时，使用依赖注入从外部直接获取一个实例，具体这个实例是如何创建的不需要关心，由一个对象库统一管理每个对象的创建过程，并直接对外提供对象。这样做的好处是我们不用管实例是怎么创建的，这种抽象可以使得每个对象的创建过程变得可扩展性，只要在对象库里修改一次，那么所有用到这个实例的地方都随之变更。例如在测试时，我们希望某个mock某个对象的数据，就可以修改注入的对象。

依赖注入有不少工具，不过[Dagger2](http://google.github.io/dagger/)使用的是`编译时代码生成(code generation)`方式而不是`反射(reflection)`，所以它的性能比较出众。[这篇文章](http://fernandocejas.com/2015/04/11/tasting-dagger-2-on-android/)有对Dagger2的实践和分析。

#### EditText
[对EditText使用合适的输入类型](http://developer.android.com/training/keyboard-input/style.html)

#### 关注新的开源library
你可以通过[Android Arsenal](http://android-arsenal.com/cc)来保持对开源项目的关注，同时利用这个工具[dryrun](https://github.com/cesarferreira/dryrun)来快速将开源项目跑在genymotion以看到实际效果。

#### Service
如果你创建了Service，那么一旦这个Service完成了自己的使命，就应该立即清理掉它

#### AccountManager
使用[AccountManager](http://developer.android.com/reference/android/accounts/AccountManager.html)来统一管理用户的帐号密码。

#### 使用`持续集成CI(Continuous Integration)`来编译并发布你的beta和release build
持续集成可以帮助你方便的编译并发布项目，不过，不要去搭建你们自己的CI服务器，因为你需要花费太多的时间来处理硬盘空间、安全问题和预防SSL攻击等问题。你可以尝试Jenkins、circleci、 travis 或者 shippable，这些价格并不贵，而且能帮你省很多事情。

#### 自动发布到Play Store
你可以使用这个工具[gradle-play-publisher](https://github.com/Triple-T/gradle-play-publisher)来帮助你自动上传apk到Play Store上

#### 开始考虑用svg替代png
理由很简单，android developer应该很熟悉每次导入一张图片时都需要生成四五种不同大小的png图片并放入到对应文件夹。与其维护这么多图片，显然使用一张svg图片更加方便。而且，google也在不断提供相关的支持，除了基本的[Vector Drawable](http://developer.android.com/tools/help/vector-asset-studio.html)，从最新的[Support Library](http://android-developers.blogspot.com/2016/02/android-support-library-232.html)我们也能看到google也在鼓励developer们使用svg。

不过，svg也有自己的限制，比如它比较适合小icon，因为它最终会生成bitmap加载以供显示，所以这需要一定的cpu支持。当然总体来讲svg还是更优的，至少大家可以不用再维护四五张不同尺寸的图片了。

#### 将一些library的类进行抽象，从而方便后期替换library
例如，一旦我们打log会使用`Log.i()`，但是，如果后面我们突然想换成`Timber.i()`就会很麻烦，需要一个个log找到来替换。但是，如果我们抽象出一个`AppLogger`来，全部调用`AppLogger.i()`来记log，那么我们只要简单的在`AppLogger`内部替换掉具体实现就可以了。

#### 监控网络连接类型，区分`移动数据流量`和`Wi-Fi`；同样，可以监控`电量`和`充电状态`
对于不同网络类型，我们可以动态改变我们的UI，比如大图可以选择在`Wi-Fi`下才加载，而在`移动数据流量`则不加载。对于`电量`也是类似的逻辑。用户一定会很感谢app做的这种自适应的。

#### User Interface is like a joke.If you have to explain it, it's not that good.

#### 先写slow但是right的代码，再去进行优化

## 小结
本文长期更新，会保持跟踪最新的技术和研究实践经验，为大家提供有效有用的经验，少走坑。

谢谢！

wingjay





欢迎各位关注
[我的Github](https://github.com/wingjay): <https://github.com/wingjay> 
和 
[我的个人博客](http://wingjay.com): <http://wingjay.com>
和
[我的简书](http://www.jianshu.com/users/da333fd63fe5/latest_articles): <http://www.jianshu.com/users/da333fd63fe5/latest_articles>
和
[微博 iam_wingjay](http://weibo.com/u/1625892654): <http://weibo.com/u/1625892654>
如果有问题，可以给我留言或发邮件<mailto:yinjiesh@126.com>

![](https://avatars0.githubusercontent.com/u/9619875?v=3&s=460)

![](/img/打赏.JPG)