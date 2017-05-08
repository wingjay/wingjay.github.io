title: 带你学开源项目：OkHttp--自己动手实现okhttp
date: 2016-07-21 14:54:33
categories:
  - Android
  - 带你学开源项目
tags:
    - Android
    - 带你学开源项目
---
> 私以为，阅读开源项目是与世界级技术大牛直接对话的最好方式。
此次来分享下 OkHttp 源码的分析。

<!-- more -->

## 一、开源项目 OkHttp
在Android、Java开发领域中，相信大家都听过或者在使用Square家大名鼎鼎的网络请求库——[OkHttp](https://github.com/square/okhttp)——https://github.com/square/okhttp ，当前多数著名的开源项目如 [Fresco](https://github.com/facebook/fresco)、[Glide](https://github.com/bumptech/glide)、 [Picasso](https://github.com/square/picasso)、 [Retrofit](https://github.com/square/retrofit)都在使用OkHttp，这足以说明其质量，而且该项目仍处在[不断维护中](https://github.com/square/okhttp/commits/master)。


## 二、问题
在分析okhttp源码之前，我想先提出一个问题，如果我们自己来设计一个网络请求库，这个库应该长什么样子？大致是什么结构呢？

下面我和大家一起来构建一个网络请求库，并在其中融入okhttp中核心的设计思想，希望借此让读者感受并学习到okhttp中的精华之处，而非仅限于了解其实现。

笔者相信，如果你能耐心阅读完本篇，不仅能对http协议有进一步理解，更能够学习到世界级项目的思维精华，提高自身思维方式。

## 三、思考
首先，我们假设要构建的的网络请求库叫做`WingjayHttpClient`，那么，作为一个网络请求库，它最基本功能是什么呢？

在我看来应该是：接收用户的请求 -> 发出请求 -> 接收响应结果并返回给用户。

那么从使用者角度而言，需要做的事是：

1. 创建一个`Request`：在里面设置好目标URL；请求method如GET/POST等；一些header如Host、User-Agent等；如果你在POST上传一个表单，那么还需要body。
2. 将创建好的`Request`传递给`WingjayHttpClient`。
3. `WingjayHttpClient`去执行`Request`，并把返回结果封装成一个`Response`给用户。而一个`Response`里应该包括statusCode如200，一些header如content-type等，可能还有body

到此即为一次完整请求的雏形。那么下面我们来具体实现这三步。

## 四、雏形实现
下面我们先来实现一个httpClient的雏形，只具备最基本的功能。

#### 1. 创建`Request`类
首先，我们要建立一个`Request`类，利用`Request`类用户可以把自己需要的参数传入进去，基本形式如下：
```
class Request {
	String url;
	String method;
	Headers headers;
	Body requestBody;

	public Request(String url, String method, @Nullable Headers headers, @Nullable Body body) {
		this.url = url;
		...
	}
}
```
#### 2. 将`Request`对象传递给`WingjayHttpClient`
我们可以设计`WingjayHttpClient`如下：
```
class WingjayHttpClient {
	public Response sendRequest(Request request) {
		return executeRequest(request);
	}
}
```
#### 3. 执行`Request`，并把返回结果封装成一个`Response`返回
```
class WingjayHttpClient {
	...
	private Response executeRequest(Request request) {
		//使用socket来进行访问
		Socket socket = new Socket(request.getUrl(), 80);
		ResponseData data = socket.connect().getResponseData();
		return new Response(data);
	}
	...
}

class Response {
	int statusCode;
	Headers headers;
	Body responseBody
	...
}
```

## 五、功能扩展
利用上面的雏形，可以得到其使用方法如下：
```
Request request = new Request("http://wingjay.com");
WingjayHttpClient client = new WingjayHttpClient();
Response response = client.sendRequest(request);
handle(response);
```

然而，上面的雏形是远远不能胜任常规的应用需求的，因此，下面再来对它添加一些常用的功能模块。

#### 1. 重新把简陋的user Request组装成一个规范的http request
一般的request中，往往用户只会指定一个URL和method，这个简单的user request是不足以成为一个http request，我们还需要为它添加一些header，如Content-Length, Transfer-Encoding, User-Agent, Host, Connection, 和 Content-Type，如果这个request使用了cookie，那我们还要将cookie添加到这个request中。

我们可以扩展上面的`sendRequest(request)`方法：
```
[class WingjayHttpClient]

public Response sendRequest(Request userRequest) {
    Request httpRequest = expandHeaders(userRequest);
    return executeRequest(httpRequest);
}

private Request expandHeaders(Request userRequest) {
    if (userRequest.header("Connection") == null) {
      requestBuilder.header("Connection", "Keep-Alive");
    }
    
    if (userRequest.header("User-Agent") == null) {
      requestBuilder.header("User-Agent", Version.userAgent());
    }
    ...
}	
```

#### 2. 支持自动重定向
有时我们请求的URL已经被移走了，此时server会返回301状态码和一个重定向的新URL，此时我们要能够支持自动访问新URL而不是向用户报错。

对于重定向这里有一个测试性URL：http://www.publicobject.com/helloworld.txt ，通过访问并抓包，可以看到如下信息：

![](http://upload-images.jianshu.io/upload_images/281665-62df4e64fd04dc24.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

因此，我们在接收到Response后要根据status_code是否为重定向，如果是，则要从Response Header里解析出新的URL－`Location`并自动请求新URL。那么，我们可以继续改写`sendRequest(request)`方法：
```java
[class WingjayHttpClient]

private boolean allowRedirect = true;
// user can set redirect status when building WingjayHttpClient
public void setAllowRedirect(boolean allowRedirect) {
	this.allowRedirect = allowRedirect;
}

public Response sendRequest(Request userRequest) {
		Request httpRequest = expandHeaders(userRequest);
		Response response = executeRequest(httpRequest);
		switch (response.statusCode()) {
			// 300: multi choice; 301: moven permanently; 
			// 302: moved temporarily; 303: see other; 
			// 307: redirect temporarily; 308: redirect permanently
			case 300:
			case 301:
			case 302:
			case 303:
			case 307:
			case 308:
				return handleRedirect(response);
			default:
				return response;
		}
		
}
// the max times of followup request
private static final int MAX_FOLLOW_UPS = 20;
private int followupCount = 0;

private Response handleRedirect(Response response) {
	// Does the WingjayHttpClient allow redirect?
	if (!client.allowRedirect()) {
		return null;
	}

	// Get the redirecting url
	String nextUrl = response.header("Location");

	// Construct a redirecting request
	Request followup = new Request(nextUrl);

	// check the max followupCount
	if (++followupCount > MAX_FOLLOW_UPS) {
		throw new Exception("Too many follow-up requests: " + followUpCount);
	}

	// not reach the max followup times, send followup request then.
	return sendRequest(followup);
}
```
利用上面的代码，我们通过获取原始`userRequest`的返回结果，判断结果是否为重定向，并做出自动followup处理。

> 一些常用的状态码
100~199：指示信息，表示请求已接收，继续处理
200~299：请求成功，表示请求已被成功接收、理解、接受
300~399：重定向，要完成请求必须进行更进一步的操作
400~499：客户端错误，请求有语法错误或请求无法实现
500~599：服务器端错误，服务器未能实现合法的请求

#### 3. 支持重试机制
所谓重试，和重定向非常类似，即通过判断`Response`状态，如果连接服务器失败等，那么可以尝试获取一个新的路径进行重新连接，大致的实现和重定向非常类似，此不赘述。

#### 4. Request & Response 拦截机制
这是非常核心的部分。

通过上面的重新组装`request`和重定向机制，我们可以感受的，一个`request`从user创建出来后，会经过层层处理后，才真正发出去，而一个`response`，也会经过各种处理，最终返回给用户。

笔者认为这和网络协议栈非常相似，用户在应用层发出简单的数据，然后经过传输层、网络层等，层层封装后真正把请求从物理层发出去，当请求结果回来后又层层解析，最终把最直接的结果返回给用户使用。

最重要的是，每一层都是抽象的，互不相关的！

因此在我们设计时，也可以借鉴这个思想，通过设置`拦截器Interceptor`，每个拦截器会做两件事情：

1. 接收上一层拦截器封装后的request，然后自身对这个request进行处理，例如添加一些header，处理后向下传递；
2. 接收下一层拦截器传递回来的response，然后自身对response进行处理，例如判断返回的statusCode，然后进一步处理。

那么，我们可以为拦截器定义一个抽象接口，然后去实现具体的拦截器。
```java
interface Interceptor {
	Response intercept(Request request);
}
```
大家可以看下上面这个拦截器设计是否有问题？

![](http://upload-images.jianshu.io/upload_images/281665-00ec5b478499a386.jpeg?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

我们想象这个拦截器能够接收一个request，进行拦截处理，并返回结果。

但实际上，它无法返回结果，而且它在处理request后，并不能继续向下传递，因为它并不知道下一个`Interceptor`在哪里，也就无法继续向下传递。

那么，如何解决才能把所有`Interceptor`串在一起，并能够依次传递下去。
```java
public interface Interceptor {
  Response intercept(Chain chain);

  interface Chain {
    Request request();

    Response proceed(Request request);
  }
}
```
使用方法如下：假如我们现在有三个`Interceptor`需要依次拦截：
```java
// Build a full stack of interceptors.
List<Interceptor> interceptors = new ArrayList<>();
interceptors.add(new MyInterceptor1());
interceptors.add(new MyInterceptor2());
interceptors.add(new MyInterceptor3());

Interceptor.Chain chain = new RealInterceptorChain(
        interceptors, 0, originalRequest);
chain.proceed(originalRequest);        
```
里面的`RealInterceptorChain`的基本思想是：我们把所有`interceptors`传进去，然后`chain`去依次把`request`传入到每一个`interceptors`进行拦截即可。

通过下面的示意图可以明确看出拦截流程：

![](http://upload-images.jianshu.io/upload_images/281665-aa94adfc49da4e40.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

其中，`RetryAndFollowupInterceptor`是用来做自动重试和自动重定向的拦截器；`BridgeInterceptor`是用来扩展`request`的`header`的拦截器。这两个拦截器存在于`okhttp`里，实际上在`okhttp`里还有好几个拦截器，这里暂时不做深入分析。

![](http://upload-images.jianshu.io/upload_images/281665-1b58154250ce74d7.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

1. `CacheInterceptor`
这是用来拦截请求并提供缓存的，当request进入这一层，它会自动去检查缓存，如果有，就直接返回缓存结果；否则的话才将request继续向下传递。而且，当下层把response返回到这一层，它会根据需求进行缓存处理；

2. `ConnectInterceptor`
这一层是用来与目标服务器建立连接

3. `CallServerInterceptor`
这一层位于最底层，直接向服务器发出请求，并接收服务器返回的response，并向上层层传递。

上面几个都是okhttp自带的，也就是说需要在`WingjayHttpClient`自己实现的。除了这几个功能性的拦截器，我们还要支持用户`自定义拦截器`，主要有以下两种（见图中非虚线框蓝色字部分）：

1. `interceptors`
这里的拦截器是拦截用户最原始的request。

2. `NetworkInterceptor`
这是最底层的request拦截器。

如何区分这两个呢？举个例子，我创建两个`LoggingInterceptor`，分别放在`interceptors`层和`NetworkInterceptor`层，然后访问一个会重定向的`URL_1`，当访问完`URL_1`后会再去访问重定向后的新地址`URL_2`。对于这个过程，`interceptors`层的拦截器只会拦截到`URL_1`的request，而在`NetworkInterceptor`层的拦截器则会同时拦截到`URL_1`和`URL_2`两个request。具体原因可以看上面的图。

#### 5. 同步、异步 Request池管理机制
这是非常核心的部分。

通过上面的工作，我们修改`WingjayHttpClient`后得到了下面的样子：
```java
class WingjayHttpClient {
	public Response sendRequest(Request userRequest) {
		Request httpRequest = expandHeaders(userRequest);
		Response response = executeRequest(httpRequest);
		switch (response.statusCode()) {
			// 300: multi choice; 301: moven permanently; 
			// 302: moved temporarily; 303: see other; 
			// 307: redirect temporarily; 308: redirect permanently
			case 300:
			case 301:
			case 302:
			case 303:
			case 307:
			case 308:
				return handleRedirect(response);
			default:
				return response;
		}
	}

	private Request expandHeaders(Request userRequest) {...}
	private Response executeRequest(Request httpRequest) {...}
	private Response handleRedirect(Response response) {...}
}
```
也就是说，`WingjayHttpClient`现在能够`同步`地处理单个`Request`了。

然而，在实际应用中，一个`WingjayHttpClient`可能会被用于同时处理几十个用户request，而且这些request里还分成了`同步`和`异步`两种不同的请求方式，所以我们显然不能简单把一个request直接塞给`WingjayHttpClient`。

我们知道，一个request除了上面定义的http协议相关的内容，还应该要设置其处理方式`同步`和`异步`。那这些信息应该存在哪里呢？两种选择：

1. 直接放入`Request`
从理论上来讲是可以的，但是却违背了初衷。我们最开始是希望用`Request`来构造符合http协议的一个请求，里面应该包含的是请求目标网址URL，请求端口，请求方法等等信息，而http协议是不关心这个request是同步还是异步之类的信息

2. 创建一个类，专门来管理`Request`的状态
这是更为合适的，我们可以更好的拆分职责。

因此，这里选择创建两个类`SyncCall`和`AsyncCall`，用来区分`同步`和`异步`。
```java
class SyncCall {
	private Request userRequest;

	public SyncCall(Request userRequest) {
		this.userRequest = userRequest;
	}
}

class AsyncCall {
	private Request userRequest;
	private Callback callback;

	public AsyncCall(Request userRequest, Callback callback) {
		this.userRequest = userRequest;
		this.callback = callback;
	}

	interface Callback {
		void onFailure(Call call, IOException e);
		void onResponse(Call call, Response response) throws IOException;
	}
}
```
基于上面两个类，我们的使用场景如下：
```java
WingjayHttpClient client = new WingjayHttpClient();
// Sync
Request syncRequest = new Request("http://wingjay.com");
SyncCall syncCall = new SyncCall(request);
Response response = client.sendSyncCall(syncCall);
handle(response);

// Async
AsyncCall asyncCall = new AsyncCall(request, new CallBack() {
	  @Override
      public void onFailure(Call call, IOException e) {}

      @Override
      public void onResponse(Call call, Response response) throws IOException {
        handle(response);
      }
});
client.equeueAsyncCall(asyncCall);
```
从上面的代码可以看到，`WingjayHttpClient`的职责发生了变化：以前是**response = client.sendRequest(request);**，而现在变成了
```java
response = client.sendSyncCall(syncCall);

client.equeueAsyncCall(asyncCall);
```

那么，我们也需要对`WingjayHttpClient`进行改造，基本思路是在内部添加`请求池`来对所有request进行管理。那么这个`请求池`我们怎么来设计呢？有两个方法：

1. 直接在`WingjayHttpClient`内部创建几个容器
同样，从理论上而言是可行的。当用户把(a)syncCall传给client后，client自动把call存入对应的容器进行管理。

2. 创建一个独立的类进行管理
显然这样可以更好的分配职责。我们把`WingjayHttpClient`的职责定义为，接收一个call，内部进行处理后返回结果。这就是`WingjayHttpClient`的任务，那么具体如何去管理这些request的执行顺序和生命周期，自然不需要由它来管。

因此，我们创建一个新的类：`Dispatcher`，这个类的作用是：

1. 存储外界不断传入的`SyncCall`和`AsyncCall`，如果用户想取消则可以遍历所有的call进行cancel操作;
2. 对于`SyncCall`，由于它是即时运行的，因此`Dispatcher`只需要在`SyncCall`运行前存储进来，在运行结束后移除即可；
3. 对于`AsyncCall`，`Dispatcher`首先启动一个ExecutorService，不断取出`AsyncCall`去进行执行，然后，我们设置最多执行的request数量为64，如果已经有64个request在执行中，那么就将这个asyncCall存入等待区。

根据设计可以得到`Dispatcher`构造：
```java
class Dispatcher {
	// sync call
	private final Deque<SyncCall> runningSyncCalls = new ArrayDeque<>();
	// async call
	private int maxRequests = 64;
	private final Deque<AsyncCall> waitingAsyncCalls = new ArrayDeque<>();
	private final Deque<AsyncCall> runningAsyncCalls = new ArrayDeque<>();
	private ExecutorService executorService;

	// begin execute Sync call
	public void startSyncCall(SyncCall syncCall) {
		runningSyncCalls.add(syncCall);
	}
	// finish Sync call
	public void finishSyncCall(SyncCall syncCall) {
		runningSyncCalls.remove(syncCall);
	}

	// enqueue a new AsyncCall
	public void enqueue(AsyncCall asyncCall) {
		if (runningAsyncCalls.size() < 64) {
			// run directly
			runningAsyncCalls.add(asyncCall);
			executorService.execute(asyncCall);
		} else {
			readyAsyncCalls.add(asyncCall);
		}
	}
	// finish a AsyncCall
	public void finishAsyncCall(AsyncCall asyncCall) {
		runningAsyncCalls.remove(asyncCall);
	}
}
```
有了这个`Dispatcher`，那我们就可以去修改`WingjayHttpClient`以实现
```java
response = client.sendSyncCall(syncCall);

client.equeueAsyncCall(asyncCall);
```
这两个方法了。具体实现如下
```java
[class WingjayHttpClient]

	private Dispatcher dispatcher;

	public Response sendSyncCall(SyncCall syncCall) {
		try {
			// store syncCall into dispatcher;
			dispatcher.startSyncCall(syncCall);
			// execute
			return sendRequest(syncCall.getRequest());
		} finally {
			// remove syncCall from dispatcher
			dispatcher.finishSyncCall(syncCall);
		}
	}

	public void equeueAsyncCall(AsyncCall asyncCall) {
		// store asyncCall into dispatcher;
		dispatcher.enqueue(asyncCall);
		// it will be removed when this asyncCall be executed
	}
```

基于以上，我们能够很好的处理`同步`和`异步`两种请求，使用场景如下：
```java
WingjayHttpClient client = new WingjayHttpClient();
// Sync
Request syncRequest = new Request("http://wingjay.com");
SyncCall syncCall = new SyncCall(request);
Response response = client.sendSyncCall(syncCall);
handle(response);

// Async
AsyncCall asyncCall = new AsyncCall(request, new CallBack() {
	  @Override
      public void onFailure(Call call, IOException e) {}

      @Override
      public void onResponse(Call call, Response response) throws IOException {
        handle(response);
      }
});
client.equeueAsyncCall(asyncCall);
```

## 六、总结
到此，我们基本把`okhttp`里核心的机制都讲解了一遍，相信读者对于okhttp的整体结构和核心机制都有了较为详细的了解。

如果有问题欢迎联系我。

谢谢！

wingjay





欢迎各位关注
[我的Github](https://github.com/wingjay): <https://github.com/wingjay> 
和
[我的简书](http://www.jianshu.com/users/da333fd63fe5/latest_articles): <http://www.jianshu.com/users/da333fd63fe5/latest_articles>
和
[微博 iam_wingjay](http://weibo.com/u/1625892654): <http://weibo.com/u/1625892654>
如果有问题，可以给我留言或发邮件<mailto:yinjiesh@126.com>

![](https://avatars0.githubusercontent.com/u/9619875?v=3&s=460)

















