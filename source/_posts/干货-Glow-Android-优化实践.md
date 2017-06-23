title: '[干货] Glow Android 优化实践'
date: 2016-11-02 19:58:15
categories:
  - Android
tags: Android
commentIssueId: 12
---

> 分享下自己在实际工作中积累的技术经验。

<!-- more -->

了解 Glow 的朋友应该知道，我们主营四款 App，分别是Eve、Glow、Nuture和Baby。作为创业公司，我们的四款 App 都处于高速开发中，平均每个 Android App 由两人负责开发，包括 Android 和 Server 开发，在满足 PM 各种需求的同时，我们的session crash free率保持不低于 99.8%，其中两款 App 接近 100%。

本文将对 Glow 当前 Android 对现有工具的探索及优化作出讲解，希望对读者有所启发。

## 整体结构概览

由于架构都是为了实际业务服务，因此在深入讲解前，需要先展示 Android 端的大体结构：

 ![Glow Android 整体结构](http://upload-images.jianshu.io/upload_images/281665-6a05f7e014dc6234.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

我们有四个 Android App，它们共用同一个 Community 社区，最底层是 Base-Library，存放公用的模块组件，如支付模块，Logging模块等等。

下面，我将依次从以下几个方面进行讲解：

- 网络层优化
- 内存优化实践
- 在App和Library中集成依赖注入
- etc.




## 网络层优化

#### 1. Retrofit2 + OkHttp3 + RxJava

上面这套结构是目前最为流行的网络层架构，可以帮我们写出简洁而稳定的网络请求代码，比起以前复杂的异步回调、主次线程切换等代码更为易用，而且能支持 `https` 请求。

基本用法如下:

```java
UserApi userApi = retrofit.create(UserApi.class);  
```

```java
@Get("/{id}")
Observable<User> getUser(@Path("id") long id);
```

```java
userApi.getUser(1)
  .subscribeOn(Schedulers.io())
  .observeOn(AndroidSchedulers.mainThread())
  .subscribe(new Action1<User>() {
    @Override
    public void call(User user) {
		// handle user
    }
  }, new Action1<Throwable>() {
    @Override
    public void call(Throwable throwable) {
		// handle throwable
    }
  });
```

这只是通用做法。下面我们要根据实际情况进行优化。

#### 2. 封装线程切换代码

上面的代码中可以看到，为了执行网络请求，我们会利用`RxJava`提供的`Schedulers`工具来方便切换线程。

```java
  .subscribeOn(Schedulers.io())
  .observeOn(AndroidSchedulers.mainThread())
```

上面的代码的作用是：让网络请求进入 `io线程` 执行，并将返回结果转入 `UI线程` 去进行渲染。

不过，我们 app 有非常多的网络请求，而且除了`网络请求`，其他的`数据库操作` 或者 `文件读写操作` 都需要一样的线程切换。因此，为了代码复用，我们利用 `RxJava` 提供的 `Transformer` 来进行封装。

```java
// RxUtil.java  
public static <T> Observable.Transformer<T, T> normalSchedulers() {
  return new Observable.Transformer<T, T>() {
    @Override
    public Observable<T> call(Observable<T> source) {
      return source.subscribeOn(Schedulers.io())
        .observeOn(AndroidSchedulers.mainThread());
    }
  };
}
```

然后，我们可以把网络请求代码转化为

```java
userApi.getUser(1)
  .compose(RxUtil.normalSchedulers())
  .subscribe(...)
```

这虽然只是很简单的改进，但能让我们的代码更简洁，更不易出错。

#### 3. 封装响应结果 JsonDataResponse

我们 server 的所有返回结果都符合如下格式:

```json
{
  'rc': 0,
  'data': {...},
  'msg': "Successful Call"
}
```

其中 `rc` 是自定义的结果标志，server 用来告诉我们该请求的逻辑处理是否成功（此时 `rc = 0`）。`data`是这个请求需要的 json 数据。`msg`一般用来存放错误提示信息。

于是我们创建了一个通用类来封装所有的 `Response`。

```java
public class JsonDataResponse<T> {
  @SerializedName("rc")
  private int rc;

  @SerializedName("msg")
  private String msg;

  @SerializedName("data")
  T data;
  
  public int getRc() { return rc; }
  
  public T getData() { return data; }
} 
```

于是，我们的请求变成如下：

```java
@Get("/{id}")
Observable<JsonDataResponse<User>> getUser(@Path("id") long id);
```

```java
userApi.getUser(1)
  .compose(RxUtil.normalSchedulers())
  .subscribe(new Action1<JsonDataResponse<User>>() {
    @Override
    public void call(JsonDataResponse<User> response) {
		if (response.getRc() == 0) {
          User user = response.getData();
          // handle user
		} else {
          Toast.makeToast(context, response.getMsg())
		}
    }
  }, new Action1<Throwable>() {
    @Override
    public void call(Throwable throwable) {
		// handle throwable
    }
  });
```

#### 4. 异常处理

上面已经能完成正常的网络请求了，但是，却还没有对错误进行处理。

一次网络请求中，可能发生以下几种错误：

- 没有网络
- 网络正常，但 http 请求失败，即 http 状态码不在 `[200, 300)` 之间，如`404`、`500`等
- 网络正常，http 请求成功，但是 server 在处理请求时出了问题，使得返回结果的 `rc != 0`

不同的错误，我们希望给用户不同的提示，并且统计这些错误。

目前我们的网络请求里已经能够处理第三种情况，另外两种都在 `throwable` 里面，我们可以通过判断 `throwable` 是 `IOException` 还是 `retrofit2.HttpException` 来区分这两种情况。

因此，我们可得到如下异常处理代码：

```java
userApi.getUser(1)
  .compose(RxUtil.normalSchedulers())
  .subscribe(new Action1<JsonDataResponse<User>>() {
    @Override
    public void call(JsonDataResponse<User> response) {
		if (response.getRc() == 0) {
          User user = response.getData();
          // handle user
          handleUser();
		} else {
          // such as: customized errorMsg: "cannot find this user".
          Toast.makeToast(context, response.getMsg(), Toast.LENGTH_SHORT).show();
		}
    }
  }, new Action1<Throwable>() {
    @Override
    public void call(Throwable throwable) {
        String errorMsg = "";
		if (throwable instanceof IOException) {
          // io Exception
          errorMsg = "Please check your network status";
		} else if (throwable instanceof HttpException) {
          HttpException httpException = (HttpException) throwable;
          // http error.
          errorMsg = httpException.response(); 
		} else {
          errorMsg = "unknown error";
		}
        Toast.makeToast(...);
    }
  });
```

#### 5. 封装异常处理代码

当然，我们并不想在每一个网络请求里都写上面一大段代码来处理 `error`，那样太傻了。比如上面 `getUser()` 请求，我希望只要写 `handleUser()` 这个方法，至于是网络问题还是 server 自己问题我都不想每次去 handle。

接下来我们来封装上面两个 `Action` 。我们可以自定义两个 `Action`:

```java
WebSuccessAction<T extends JsonDataResponse> implements Action1<T> 
```

```java
WebFailureAction implements Action1<Throwable>
```

其中，`WebSuccessAction` 用来处理一切正常（网络正常，请求正常，`rc=0`）后的处理，`WebFailureAction` 用来统一处理上面`三种 error`。

实现如下：

```java
class WebSuccessAction<T extends JsonDataResponse> implements Action1<T> {
  @Override
  public void call(T response) {
    int rc = response.getRc();
    if (rc != 0) {
      throw new ResponseCodeError(extendedResponse.getMessage());
    }
    onSuccess(extendedResponse);
  }

  public abstract void onSuccess(T extendedResponse);
}
```

```java
// (rc != 0) Error
class ResponseCodeError extends RuntimeException {
  public ResponseCodeError(String detailMessage) {
    super(detailMessage);
  }
}
```

在 `WebSuccessAction` 里，我们把 `rc != 0` 这种情况转化成 `ResponseCodeError` 并抛出给 `WebFailureAction` 去统一处理。

```java
class WebFailAction implements Action1<Throwable> {
  @Override
  public void call(Throwable throwable) {
    String errorMsg = "";
    if (throwable instanceof IOException) {
      errorMsg = "Please check your network status";
    } else if (throwable instanceof HttpException) {
      HttpException httpException = (HttpException) throwable;
      // such as: "server internal error".
      errorMsg = httpException.response(); 
    } else {
      errorMsg = "unknown error";
    }
    Toast.makeToast(...);
  }
}
```

有了上面两个自定义 `Action` 后，我们就可以把前面 `getUser()` 请求转化如下：

```java
userApi.getUser(1)
  .compose(RxUtil.normalSchedulers())
  .subscribe(new WebSuccessAction<JsonDataResponse<User>>() {
      @Override
      public void onSuccess(JsonDataResponse<User> response) {
    	handleUser(response.getUser());
      }
    }, new WebFailAction())
```

Bingo! 至此我们能够用非常简洁的方式来执行网络操作，而且完全不用担心异常处理。



## 内存优化实践

在内存优化方面，Google 官方文档里能找到非常多的学习资料，例如常见的内存泄漏、[bitmap官方最佳实践](https://developer.android.com/training/displaying-bitmaps/manage-memory.html)。而且 Android studio 里也集成了很多有效的工具如 [Heap Viewer](https://developer.android.com/studio/profile/heap-viewer-walkthru.html), [Memory Monitor](https://developer.android.com/studio/profile/am-memory.html) 和 [Hierarchy Viewer](https://developer.android.com/studio/profile/hierarchy-viewer.html) 等等。

下面，本文将从其它角度出发，来对内存作进一步优化。

#### 1. 当Activity关闭时，立即取消掉网络请求结果处理。

这一点很容易被忽略掉。大家最常用的做法是在 `Activity` 执行网络操作，当 `Http Response` 回来后直接进行UI渲染，却并不会去判断此时 `Activity` 是否仍然存在，即用户是否已经离开了当时的页面。

那么，有什么方法能够让每个网络请求都自动监听 Activity(Fragment) 的 lifecycle 事件并且当特定 lifecycle 事件发生时，`自动中断`掉网络请求的继续执行呢？

首先来看下我们的网络请求代码：

```java
userApi.getUser(1)
  .compose(RxUtil.normalSchedulers())
  .subscribe(new WebSuccessAction<JsonDataResponse<User>>() {
      @Override
      public void onSuccess(JsonDataResponse<User> response) {
    	handleUser(response.getUser());
      }
    }, new WebFailAction())
```

我们希望达到的是，当 `Activity` 进入 `onStop` 时立即停掉网络请求的后续处理。

这里我们参考了 [RxLifecycle](https://github.com/trello/RxLifecycle) 的实现方式，之所以没有直接使用 [RxLifecycle](https://github.com/trello/RxLifecycle) 是因为它必须我们的 BaseActivity 继承其提供的 [RxActivity](https://github.com/trello/RxLifecycle/blob/master/rxlifecycle-components/src/main/java/com/trello/rxlifecycle/components/RxActivity.java) ，而 RxActivity 并未继承我们需要的 `AppCompatActivity`。因此本人只能在学习其源码后，自己重新实现一套，并做了一些改动以更符合我们自己的应用场景。

具体实现如下：

- 首先，我们在 BaseActivity 里，利用 RxJava 提供的 `PublishSubject` 把所有 lifecycle event 发送出来。

  ```java
  class BaseActivity extends AppCompatActivity {
    protected final PublishSubject<ActivityLifeCycleEvent> lifecycleSubject = PublishSubject.create();
    
    @Override
    protected void onCreate(Bundle savedInstanceState) {
      super.onCreate(savedInstanceState);

      lifecycleSubject.onNext(ActivityLifeCycleEvent.CREATE);
    }
    
    @Override
    protected void onDestroy() {
      lifecycleSubject.onNext(ActivityLifeCycleEvent.DESTROY);
      
      super.onDestroy();
    }
    
    @Override
    protected void onStop() {
      lifecycleSubject.onNext(ActivityLifeCycleEvent.STOP);

      super.onStop();
    }
  }
  ```

- 然后，在 `BaseActivity` 里，提供 `bindUntilEvent(LifeCycleEvent)` 方法

  ```java
  class BaseActivity extends AppCompatActivity {
    
    @NonNull
    @Override
    public <T> Observable.Transformer<T, T> bindUntilEvent(@NonNull final ActivityLifeCycleEvent event) {
      return new Observable.Transformer<T, T>() {
        @Override
        public Observable<T> call(Observable<T> sourceObservable) {
          Observable<ActivityLifeCycleEvent> o =
              lifecycleSubject.takeFirst(activityLifeCycleEvent -> {
                return activityLifeCycleEvent.equals(event);
              });
          return sourceObservable.takeUntil(o);
        }
      };
    }
  }
  ```

  这个方法可以用于每一个网络请求 Observable 中，当它监听到特定的 lifecycle event 时，就会自动让网络请求 Observable 终止掉，不会再去监听网络请求结果。

- 具体使用如下：

  ```java
  userApi.getUser(1)
    .compose(bindUntilEvent(ActivityLifeCycleEvent.PAUSE))
    .compose(RxUtil.normalSchedulers())
    .subscribe(new WebSuccessAction<JsonDataResponse<User>>() {
      @Override
        public void onSuccess(JsonDataResponse<User> response) {
          handleUser(response.getUser());
        }
    }, new WebFailAction())
  ```

  利用 `.compose(bindUntilEvent(ActivityLifeCycleEvent.STOP))` 来监听 Activity 的 Stop 事件并终止 `userApi.getUser(1)` 的 `subscription`，从而防止内存泄漏。

#### 2. 图片优化实践

Android开发者都知道，每个app的可用内存时有限的，一旦内存占用太多或者在主线程突然请求较大内存，很有可能发生 OOM 问题。而其中，图片又是占用内存的大头，因此我们必须采取多种方法来进行优化。

多数情况下我们是从 server 获取一张高清图片下来，然后在内存里进行裁剪成需要的大小来进行显示。这里面存在两个问题，

1：假设我们只需要一张小图，而server取回来的图如果比较大，那就会浪费带宽和内存。

2：如果直接在主线程去为图片请求大块空间，很容易由于系统难于快速分配而 OOM；

比较理想的情况是：需要显示多大的图片，就向server请求多大的图片，既节省用户带宽流量，更减少内存的占用，减小 OOM 的机率。

为了实现 server 端的图片Resize，我们采用了 [thumbor](https://github.com/thumbor/thumbor) 来提供图片 Resize 的功能。android端只需要提供一个原图片 URL 和需要的 size 信息，就可以得到一张 Resize 好的图片资源文件。具体server端实现这里就不细讲了，感兴趣的读者可以阅读官方文档。

这里介绍下我们在 Android 端的实现，以 Picasso 为栗子。

- 首先要引入 Square 提供的 [pollexor](https://github.com/square/pollexor) 工具，它可以让我们更简便的创建 thumbor 的规范 URI，参考如下：

  ```java
  thumbor.buildImage("http://example.com/image.png")
      .resize(48, 48)
      .toUrl()
  ```

- 然后，利用 Picasso 提供的 requestTransformer 来实时获取当前需要显示的图片的真实尺寸，同时设置图片格式为 WebP，这种格式的图片可以保持图片质量的同时具有更小的体积：

  ```java
  Picasso picasso = new Picasso.Builder(context).requestTransformer(new Picasso.RequestTransformer() {
        @Override
        public Request transformRequest(Request request) {
          String modifiedUrl = URLEncoder.encode(originUrl);
          ThumborUrlBuilder thumborUrlBuilder = thumbor.buildImage(modifiedUrl);
          String url = thumborUrlBuilder.resize(request.targetWidth, request.targetHeight)
              .filter(ThumborUrlBuilder.format(ThumborUrlBuilder.ImageFormat.WEBP))
              .toUrl();
          Timber.i("SponsorAd Image Resize url to " + url);
          return request.buildUpon().setUri(Uri.parse(url)).build();
        }
      }).build();
  ```

- 利用修改后的 picasso 对象来请求图片

  ```java
  picasso.load(originUrl).fit().centerCrop().into(imageView);
  ```

利用上面这种方法，我们可以为不同的 ImageView 计算显示需要的真实尺寸，然后去请求一张尺寸匹配的图片下来，节约带宽，减小内存开销。

当然，在应用这种方法的时候，不要忘记考虑服务器的负载情况，毕竟这种方案意味着每张图片会被生成各种尺寸的小图缓存起来，而且Android设备分辨率不同，即使是同一个 ImageView，真实的宽高 Pixel 值也会不同，从而生成不同的小图。



## 在App和Library中集成依赖注入

依赖注入框架 [Dagger](https://github.com/square/dagger) 我们很早就开始用了，从早期的 Dagger1 到现在的 Dagger2。虽然 Dagger 本身较为陡峭的学习曲线使得不少人止步，不过一旦用过，根本停不下来。

如果只是在 App 里使用 Dagger 相对比较简单，不过，我们还需要在 `Community` 和 `Base-Android` 两个公用 Library 里也集成 Dagger，这就需要费点功夫了。

下面我来逐步讲解下我们是如何将 Dagger 同时集成进 App 和 Library 中。

#### 1. 在App里集成Dagger

首先需要在 `GlowApplication` 里生成一个全局的 `AppComponent`

```java
@Singleton
@Component(modules = AppModule.class)
public interface AppComponent {
  void inject(MainActivity mainActivity);
}
```

创建 `AppModule`

```java
@Module
public class AppModule {
  private final LexieApplication lexieApplication;

  public AppModule(LexieApplication lexieApplication) {
    this.lexieApplication = lexieApplication;
  }
  
  @Provides Context applicationContext() {
    return lexieApplication;
  }
  
  // mock tool object
  @Provides Tool provideTool() {
    return new Tool();
  }
}
```

集成进 `Application`

```java
class GlowApplication extends Application {
  private AppComponent appComponent;
  
  @Override
  public void onCreate() {
    appComponent = DaggerAppComponent.builder()
        .appModule(new AppModule(this))
        .build();
  }
  
  public static AppComponent getAppComponent() {
    return appComponent;
  }
}
```

在 `MainActivity`中使用`inject` 一个 `tool` 对象

```java
class MainActivity extends Activity {
  @Inject Tool tool;
  
  @Override
  public void onCreate() {
    GlowApplication.getAppComponent().inject(this);
  }
}
```

#### 2. 在 Library 中集成 Dagger

（下面以公用Library：Community为例子）

逆向思维下，先设想应用场景：即 Dagger 已经集成好了，那么我们应该可以按如下方式在 `CommunityActivity` 里 `inject` 一个 `tool` 对象。

```java
class CommunityActivity extends Activity {
  @Inject Tool tool;
  
  @Override
  public void onCreate() {
    GlowApplication.getAppComponent().inject(this);
  }
}
```

关键在于： `GlowApplication.getAppComponent().inject(this);` 这一句。

那么问题来了：

**对于一个 Library 而言，它是无法拿到 GlowApplication 对象的，因为作为一个被别人调用的 Library，它甚至不知道这个上层 class 的存在**

为了解决这个问题，我们在`community`里定义一个公用接口作为`中间桥梁`，让`GlowApplication`实现这个公共接口即可。

```java
// 在Community定义接口CommunityComponentProvider
public interface CommunityComponentProvider {
  AppComponent getAppComponent();
}
```

```java
// 每个app的Application类都实现这个接口来提供AppComponent
class GlowApplication implements CommunityComponentProvider {
  AppComponent getAppComponent() {
    return appComponent;
  }
}
```

然后 `CommunityActivity`就可以实现如下：

```java
class CommunityActivity extends Activity {
  @Inject Tool tool;
  
  @Override
  public void onCreate() {
    Context applicationContext = getApplicationContext();
    CommunityComponentProvider provider = (CommunityComponentProvider) applicationContext;
    provider.getAppComponent().inject(this);
  }
}
```

#### 3. 从 AppComponent 抽离 CommunityComponent

```java
provider.getAppComponent().inject(this);
```

这一句里我们已经实现前半句 `provider.getAppComponent()` 了，但后半句的实现呢？

正常情况下，我们要把

```java
void inject(CommunityActivity communityActivity);
```

放入 `AppComponent` 中

```java
@Singleton
@Component(modules = AppModule.class)
public interface AppComponent {
  void inject(MainActivity mainActivity);
  
  // 加在这里
  void inject(CommunityActivity communityActivity);
}
```

其实这样我们就已经几乎完成了整个 Library 和 App 的依赖注入了。

但细心的朋友应该发现里面存在一个小问题，那就是

```java
void inject(CommunityActivity communityActivity);
```

这句代码如果放入了 `App` 里的 `AppComponent` 里，那就意味着我们也需要在另外三个 `App` 里的 `AppComponent` 都加上一句相同的代码？这样可以吗？

理论上当然是可行的。但是，从单一职责的角度来考虑，`AppComponent` 只需要负责 `App` 层的 `inject` 就行，我们不应该把属于 `Community` 的 `inject` 放到`App` 里，这样的代码太ugly，而且更重要的是，随着 Community 越来越多 Activity 需要 inject ，每个 inject 都要在各个 App 里重复加，这太烦了，也太笨了。

因此，我们采用了一个简洁有效的方法来改进。

在 `Community` 里创建一个 `CommunityComponent`，所有属于 `Community` 的`inject` 直接写在 `CommunityComponent` 里，不需要 `App` 再去关心。与此同时，为了保持前面 `provider.getAppComponent()` 仍然有效，我们让 `AppComponent` 继承 `CommunityComponent`。

实现代码如下：

```java
class AppComponent extends CommunityComponent {...}
```

在 `Community` 里

```java
class CommunityComponent {
  void inject(CommunityActivity communityActivity);
}
```

```java
class CommunityActivity extends Activity {
  @Inject Tool tool;
  
  @Override
  public void onCreate() {
    Context applicationContext = getApplicationContext();
    CommunityComponentProvider provider = (CommunityComponentProvider) applicationContext;
    provider.getAppComponent().inject(this);
  }
}
```

![依赖注入](http://upload-images.jianshu.io/upload_images/281665-483c8a864c09503d.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

Bingo! 至此我们已经能够优雅简洁地在 App 和 Library 里同时应用依赖注入了。



## 小结

由于篇幅有限，本文暂时先从网络层、内存优化和依赖注入方面进行讲解，之后会再考虑从 Logging模块、数据同步模块、Deep Linking模块、多Library的Gradle发布管理、持续集成和崩溃监测模块等进行讲解。

谢谢。

wingjay


[我的Github](https://github.com/wingjay): <https://github.com/wingjay> 
[微博 iam_wingjay](http://weibo.com/u/1625892654): <http://weibo.com/u/1625892654>

如果有问题，可以给我留言或发邮件<mailto:yinjiesh@126.com>