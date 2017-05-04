title: RxLifecycle源码解析－当Activity被destory时自动停掉网络请求
date: 2016-07-14 20:50:37
tags: 
	- Android
	- RxJava 
  - 带你学开源项目
---

> 私以为，阅读开源项目是与世界级技术大牛直接对话的最好方式。
此次来分享下 RxLifecycle 源码的分析。

<!-- more -->
**此文需要读者对RxJava有一定了解**

## 一、 介绍
本文分析思路不是从源码里抽代码出来一步步跟踪，而是提出问题，一步步思考解决方法，从而学习到开源项目的思维精华，而不仅仅是了解该项目的具体实现。笔者认为这种方式更有利于读者提高自身思维方式和技术能力。

## 二、 开源项目
[RxLifecycle](https://github.com/trello/RxLifecycle) 地址：https://github.com/trello/RxLifecycle 。该项目是为了防止`RxJava`中`subscription`导致内存泄漏而诞生的，核心思想是通过监听`Activity`、`Fragment`的生命周期，来自动断开`subscription`以防止内存泄漏。

基本用法如下：
```java
myObservable
    .compose(RxLifecycle.bindUntilEvent(lifecycle, ActivityEvent.DESTROY))
    .subscribe();
```
此处`myObservable`可以看成一个耗时的网络请求，通过绑定到`ActivityEvent.DESTROY`，一旦Activity发生了`DESTORY`生命周期，数据就不会再流向`subscriber`，即不会对这些数据进行任何处理和UI绘制，从而提高安全性。



## 三、 问题
Android开发中常会有这样一个场景：
1. 发送网络请求 -> 2. 服务器处理请求并返回数据 -> 3. client端接收数据，绘制UI。

在前两步一般都是不会出现问题的，但是在第三步，当数据返回给client端时，如果页面已经不在了，那么就无法去绘制UI，很有可能会导致意向不到的问题。因此，为了解决这个问题，一个好的思路就是`当页面离开时，自动断开网络请求数据的处理过程，即数据返回后不再进行任何处理`。


## 四、 思考
要达到上面这样一个功能，我们可以思考，至少需要两部分：
1. 随时监听`Activity`(`Fragment`)的生命周期并对外发射出去；
2. 在我们的网络请求中，接收生命周期并进行判断，如果该生命周期是自己绑定的，如`Destory`，那么就断开数据向下传递的过程。

## 五、 分析
可以看到，首先有一个核心功能要实现：就是既能够监听`Activity`生命周期事件并对外发射，又能够接收每一个生命周期事件并作出判断。为了实现这个功能，可以联想到`RxJava`中的`Subject`，既能够发射数据，又能够接收数据。

## 六、 Subject解析
了解`Subject`的读者可以跳过这部分。

如何理解`Subject`呢？

很容易，在RxJava里面，`Observable`是数据的发射者，它会对外发射数据，然后经过`map`、`flatmap`等等数据处理后，最终传递给`Observer`，这个数据接收者。因此，抛开中间数据处理不管，可以看出，`Observable`对外发射数据，是数据流的开端；`Observer`接收数据，是数据流的末端。

那么`Subject`呢？看一眼源码：
```
/**
 * Represents an object that is both an Observable and an Observer.
 */
public abstract class Subject<T, R> extends Observable<R> implements Observer<T> {}
```
首先，它`extends Observable<R>`，说明`Subject`具备了对外发射数据的能力，即拥有了`from()`、`just()`等等；另外，它又`implements Observer<T>`，说明又能够处理数据，具备`onNext()`、`onCompleted`等等。

然后，`Subject`毕竟只是一个抽象类，那么我们要如何使用它呢？

这里介绍一种最简单的：`PublishSubject`:
```
  PublishSubject<Object> subject = PublishSubject.create();
  // myObserver will receive "one" & "two" and onCompleted events
  subject.subscribe(myObserver);
  subject.onNext("one");
  subject.onNext("two");
  subject.onCompleted();
```
这里做的事情很简单，先创建一个`PublishSubject` -> 绑定一个`myObserver`，此时`subject`扮演了`Observable`的角色，把数据发射给`myObserver` -> 然后`subject`处理接收了两个数据`one`、`two` -> 最终这些数据都传递给了`myObserver`。所以，`subject`扮演的角色是:

**数据`one`、`two`   =>   (Observer) `subject` (Observable)   =>   `myObserver`**

简单来说，我们把数据`one`、`two`塞给`subject`，然后`subject`又发射给了`myObserver`。

## 七、 BaseActivity监听生命周期
那么我们先来实现生命周期监听功能，基本思路是：在`BaseActivity`里创建一个`PublishSubject`对象，在每个生命周期发生时，把该生命周期事件传递给`PublishSubject`。具体实现如下(只写部分生命周期，其他类似)：
```java
class BaseActivity {
	
	protected final PublishSubject<ActivityLifeCycleEvent> lifecycleSubject = PublishSubject.create();

	@Override
  	protected void onCreate(Bundle savedInstanceState) {
  		lifecycleSubject.onNext(ActivityLifeCycleEvent.CREATE);
  		...
  	}

  	@Override
  	protected void onPause() {
  		lifecycleSubject.onNext(ActivityLifeCycleEvent.PAUSE);
  		...
  	}

  	@Override
  	protected void onStop() {
  		lifecycleSubject.onNext(ActivityLifeCycleEvent.STOP);
  		...
  	}
  	...
}
```
这样的话，我们把所有生命周期事件都传给了`lifecycleSubject`了，或者说，`lifecycleSubject`已经接收到了并能够`对外发射各种生命周期事件`的能力了。

## 八、 改良每一个Observable，接收生命周期并自动断开自身
通常我们的一次网络请求长这样：
```java
networkObservable
	.subscribe(new Observer(  handleUI()  ));
```
其中，`networkObservable`表示一个通用的网络请求，会接收网络数据并传递给`Observer`去绘制UI。

现在，我们希望这个`networkObservable`监听`Activity`的`DESTORY`事件，一旦发生了`DESTORY`就自动断开`Observer`，即使网络数据回来了也不再传递给`Observer`去绘制UI。即：
```java
networkObservable
	.compose(bindUntilEvent(ActivityLifeCycleEvent.DESTORY))
	.subscribe(new Observer(  handleUI()  ));
```
因此，我们需要实现
```java
bindUntilEvent(ActivityLifeCycleEvent.DESTORY)
```
这个方法，那如何实现呢？

我们知道`lifecycleSubject`能够发射生命周期事件了，那么我们可以让`networkObservable`去检查`lifecycleSubject`发出的生命周期，如果和自己绑定的生命周期事件一样，那就自动停掉即可。

## 九、 改装networkObservable
对于`networkObservable自动停掉`，我们可以利用操作符
```
networkObservable.takeUntil(otherObservable)
```
它的作用是监听`otherObservable`，一旦`otherObservable`对外发射了数据，就自动把`networkObservable`停掉；

那`otherObservable`何时对外发射数据呢？当然是`lifecycleSubject`发射出的生命周期事件`等于`绑定的生命周期事件时，开始发射。
```java
	otherObservable = lifecycleSubject.takeFirst(new Func1<ActivityLifeCycleEvent, Boolean>() {
              @Override
              public Boolean call(ActivityLifeCycleEvent activityLifeCycleEvent) {
                return activityLifeCycleEvent.equals(bindEvent);
              }
            });
```
其中的关键是判断`activityLifeCycleEvent.equals(bindEvent);`，一旦条件满足，`otherObservable`就对外发射数据，然后`networkObservable`就立即自动停掉。

## 十、 合并 生命周期监听 与 networkObservable改良
1. 在BaseActivity里添加`lifecycleSubject`，并把每一个生命周期事件按时传递给`lifecycleSubject`
2. 在BaseActivity里添加一个`bindUntilEvent`方法:
```java
  @NonNull
  @Override
  public <T> Observable.Transformer<T, T> bindUntilEvent(@NonNull final ActivityLifeCycleEvent event) {
    return new Observable.Transformer<T, T>() {
      @Override
      public Observable<T> call(Observable<T> sourceObservable) {
        Observable<ActivityLifeCycleEvent> compareLifecycleObservable =
            lifecycleSubject.takeFirst(new Func1<ActivityLifeCycleEvent, Boolean>() {
              @Override
              public Boolean call(ActivityLifeCycleEvent activityLifeCycleEvent) {
                return activityLifeCycleEvent.equals(event);
              }
            });
        return sourceObservable.takeUntil(compareLifecycleObservable);
      }
    };
  }
```

3. 在任意一个网络请求 networkObservable 处改良
```
networkObservable
	.compose(bindUntilEvent(ActivityLifeCycleEvent.DESTORY))
	.subscribe(new Observer(  handleUI()  ));
```

## 注意：
1. 文中提到的`networkObservable`是网络请求，但实际上这不限于网络请求，任何耗时操作如文件io操作等都可以利用这个方法，来监听生命周期并自动暂停。
2. 对于Fragment中的处理方法也是类似。


谢谢！

wingjay
---

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





