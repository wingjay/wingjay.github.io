title: 让普通 Java 类自动感知 Activity Lifecycle
date: 2017-11-09 23:00:02
permalink: auto-lifecycle
categories:
	- Android
tags:
	- Android
	- Lifecycle
	- Java
commentIssueId: 23
---
## 背景
在 Android 开发中，我们都很熟悉 Activity 的 Lifecycle，并且会在特定的 Lifecycle 下执行特定的操作。当然，我们清楚 Lifecycle 本身是带有 Android 特质的，那尝试设想下，如果`普通的 Java Class 也能自动感知
 Lifecycle 呢`？咋一听这个想法似乎背后意义不大，但在实际探索中，我们发现这个特性能为我们达成一些之前未考虑到或者不易实现的优化。

本文分享下我们基于这个思想所开发的框架：`AutoLifecycle` 及其带来的一些有意思的实践。

<!-- more -->

- 优化一：当Activity进入onDestroy时，自动取消网络请求返回
- 优化二：自动将网络请求时机提前到View渲染之前，提高页面打开速度
- 优化三：MVP改进，让Presenter和View自动bind/unBind


注：下文提到的`Lifecycle-Aware`就是这里指代的`让普通 Java Class 自动获取 Lifecycle `。

## 实践及优化
### 优化一：当Activity进入onDestroy时，自动取消网络请求返回
在网络请求时，相信大家都有一个经验：在每个网络结果回来时，我们做的第一件事不是显示数据，而是写个if-else判断Activity还在不在。
```java
mTopApiObservable
  ...
  .subscribe(new Subscriber<Object>() {
	  @Override
	  public void onNext(Object data) {
	  	if(activity == null) {
			return; // 判断Activity是否还在，不在就不去显示数据
		}
		
		display(data); // 显示数据
	  }
	  ...
  });
```
由于网络请求都是异步的，所以不得不做这样的判断，来防止不可预测的空指针问题或内存泄漏问题。

既然你总是担心`Activity`还在不在，那么如果我们通过`Lifecycle-Aware让每个网络请求能自动感知Activity的onDestroy事件`，
并在`onDestroy`时，自动把网络请求结果`取消掉不再返回`，那就能够消除这个担忧了。
```java
mTopApiObservable
  ...
  .compose(bindUntilEvent(ActivityLifecycle.DESTROY)) // 绑定Activity的onDestroy事件
  .subscribe(new Subscriber<Object>() {
	  @Override
	  public void onNext(Object data) {
		display(data); // 直接去显示数据
	  }
	  ...
  });
```

其中最关键的就是`compose(bindUntilEvent(ActivityLifecycle.DESTROY))`这句，它能达到的效果是：一旦`Activity`发生`onDestroy`时，`Observer`的数据就会停止向`Subscriber`里流动。从而保证`onNext`无需担心`Activity`已`Destroy`这种情况。

**在上面网络请求的实践里，你还可以根据自己的情况把`Destroy`换成`Stop`/`Pause`等，而且可以看出，这种自动取消机制可适用于任何`Observable`，不仅仅是网络请求。**

### 优化二：自动将网络请求提前到View Inflate之前，加速页面渲染
先说下这项优化的原理。
通常，我们会在`Activity`的`onCreate`里依次执行下面的代码：
```java
@Override
protected void onCreate(Bundle savedInstanceState) {
    super.onCreate(savedInstanceState);
    setContentView(R.layout.XXX);   // Inflate View
    findViewByIds();                // 初始化View
    presenter.loadDataFromServer(); // 发起网络请求
}
```
即在`Inflate View`和`初始化View`之后，才发起网络请求去加载数据。

而实际上，网络请求是不占用主线程的，如果能在`Inflate View`之前就在其他线程发起网络请求，可以把整个页面显示耗时缩短`100ms-200ms`。
> ![LoadBeforeInflate优化效果](http://upload-images.jianshu.io/upload_images/281665-dbf719e2d9a88946.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

现在有了`AutoLifecycle`框架，我们就可以很轻松实现：让Presenter自动监听`Inflate View`这个生命周期，在那时发起网络请求即可。

```java
public class NewPresenter {

    public NewPresenter(IView iView) {
        ...
		// 向AutoLifecycle注册
        AutoLifecycle.getInstance().init(this); 
    }

	// 当Activity Inflate View前自动回调
    @AutoLifecycleEvent(activity = ActivityLifecycle.PRE_INFLATE)
    private void onHostPreInflate() {
         loadDataFromServer(); // 发起网络请求
    }
	...
}
```

此时，我们的Activity也不用手动调用`presenter.loadDataFromServer();`了，因为Presenter内会在感知到`Inflate View`事件时自动发起网络请求。

```java
@Override
protected void onCreate(Bundle savedInstanceState) {
    super.onCreate(savedInstanceState);
    setContentView(R.layout.XXX);
    findViewByIds();
    // 无需手动启动网络请求
}
```

经过测试，在保证单个网络请求耗时相同的情况下，页面从`onCreate`到`显示数据`的渲染耗时可以从`550ms`缩短到`367ms`，也就是`30%-40%`的优化，效果是非常不错的，而且代码也更加简洁清晰。
> ![](http://upload-images.jianshu.io/upload_images/281665-3d050c819f7c158e.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)
 

通过简单的注册`AutoLifecycle`，`Presenter`能够自动感知到所有`Lifecycle`，甚至包括自定义的特殊`Lifecycle`，如下图：
![LifecycleAwarePresenter](http://upload-images.jianshu.io/upload_images/281665-3c00d59f5cacebcc.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)



### 优化三：MVP改进，让Presenter和View自动bind/unBind
第一项优化比较直接，可以先让大家形成一个直观印象。
我们项目是采用MVP项目，对于`Presenter`的使用存在一段固定代码，即在`onCreate`时调用`bindView()`，在`onDestroy`时调用`unBindView()`。如下图：
```java
public class OldActivity extends BaseActivity {

    BasePresenter mPresenter = new BasePresenter();

    @Override
    protected void onCreate(@Nullable Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
		mPresenter.bindView(this); // onCreate时手动bind Presenter 和 IView
    }

    @Override
    protected void onDestroy() {
        mPresenter.unbindView(); // onDestroy时手动unBindView
        super.onDestroy();
    }
}
```

那么，既然我们现在能`让一个普通类自动感知Lifecycle`，那其实也就能让`Presenter`在感知到`onCreate`时`自动bindView`，在感知到`onDestroy`时`自动unBindView`。
改进后的代码如下：
```java
public class NewActivity extends BaseActivity {

    NewPresenter mPresenter;

    @Override
    protected void onCreate(@Nullable Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        mPresenter = new NewPresenter(this); // 只需要创建即可
    }
}

public class NewPresenter {

    private IView mIView;

    public NewPresenter(IView iView) {
        this.mIView = iView;
		// 向AutoLifecycle注册即可获得Lifecycle回调
        AutoLifecycle.getInstance().init(this); 
    }

	// 当Activity进入onCreate后自动调用
    @AutoLifecycleEvent(activity = ActivityLifecycle.CREATE)
    private void onHostCreate() {
        bindView(mIView); 
    }

	// 当Activity进入onDestroy后自动调用
    @AutoLifecycleEvent(activity = ActivityLifecycle.DESTROY)
    private void onHostDestroy() {
        unBindView();
    }
}
```

其实，在大家的平常开发中，还会存在许多类似`Presenter`的类：`需要在某个特定的Lifecycle下执行一些动作`。这时就可以基于`Lifecycle-Aware`来让这个普通类自动去执行，而不是去每个`Activity/Fragment`里写一遍，提高类的内聚性。


## AutoLifecycle的核心原理
(TL;DR)
下面介绍下`AutoLifecycle`的关键实现部分，感兴趣的读者可以参考。

### 1. 让Activity对外发送Lifecycle事件
使用过`RxJava`的同学知道里面有一个[`PublishSubject`](http://reactivex.io/RxJava/javadoc/rx/subjects/PublishSubject.html)，基于观察者模式，主动发送并接受消息。这里我们用`PublishSubject`来发送Lifecycle事件。见如下：
![](http://upload-images.jianshu.io/upload_images/281665-2deba2e78165c91a.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

**这里的Lifecycle事件可以自己定义，比如前面提到的`PRE_INFLATE`事件，是在setContentView之前发送**，类似：

![](http://upload-images.jianshu.io/upload_images/281665-f7c747443273ebe4.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

### 2. 感知某个Lifecycle的发生并自动执行回调
上面提了，`PublishSubject`不仅能发送消息，还能接受自己的消息。基于这个特点，我们便可以监听每一个LifecycleEvent。如下图：
![](http://upload-images.jianshu.io/upload_images/281665-0f2d95662cd053f4.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

这里的参数Observable是我们希望被回调的函数，IContextLifecycle是指定的Lifecycle。即当指定的Lifecycle Event发生时，会自动subscribe提供的Observable。

基于这个功能，便可以实现上面场景一和场景二里的`@AutoLifecycleEvent`注解了，即把`@AutoLifecycleEvent`标注的函数包装成一个Observable，通过这个`executeOn`来注册函数的执行生命周期即可。

### 3. 监听Lifecycle并取消网络请求结果
在场景三里，我们为网络请求的`Observable`提供了一个[`Transformer`](http://reactivex.io/RxJava/javadoc/rx/Observable.Transformer.html)，它能在监听到某个Lifecycle发生时，停止数据流的向下流动。该`Transformer`的核心实现是：
![](http://upload-images.jianshu.io/upload_images/281665-3de275bde3f6a0a1.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)
可以看出，当指定的Lifecycle一旦发生，我们网络请求Observable就会停止向下传递数据。

### 4. 支持自定义Lifecycle，支持Activity/Fragment/DialogFrament等
可以看出，`AutoLifecycle`除了支持常规的生命周期，还能支持自定义的特殊生命周期，比如View Inflate前。

另外，上面都是以Activity为例，不过显然这套框架可以灵活扩展，不局限于Activity，还能适用于Fragment、DialogFrament等。

## 源码
对源码感兴趣的欢迎进入我的【小专栏 https://xiaozhuanlan.com/wingjay】或者 【付费群 http://www.jianshu.com/p/655af849aaf6】

## 总结
`Lifecycle-Aware`思想是Google官方提出来的概念：赋予普通类自动感知生命周期的能力。而本文也是基于这个思想，提供了一些具体实践和优化的思路，读者同学可以根据自己的情况做更多的改进和尝试。


——————
wingjay
谢谢。


> 欢迎加入【阿里求职付费群】：
> 1. 及时推送集团内最新岗位空缺信息
> 2. 定期分享针对阿里的最新Android面试题及相关面试经验
> 3. 长期提供阿里集团内各岗位的内推。
> 详情：http://www.jianshu.com/p/655af849aaf6


## 参考
https://developer.android.com/topic/libraries/architecture/lifecycle.html
https://www.atatech.org/articles/63098
https://github.com/trello/RxLifecycle
http://reactivex.io/RxJava/javadoc/rx/subjects/PublishSubject.html
http://reactivex.io/RxJava/javadoc/rx/Observable.Transformer.html
