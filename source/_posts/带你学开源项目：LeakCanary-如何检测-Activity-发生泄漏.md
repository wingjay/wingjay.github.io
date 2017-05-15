title: 带你学开源项目：LeakCanary-如何检测 Activity 是否泄漏
date: 2017-05-14 19:29:33
permalink: dig_into_leakcanary
categories:
  - Android
  - 带你学开源项目
tags:
    - Android
    - 带你学开源项目
    - 内存泄漏
    - 性能优化
---
>OOM 是 Android 开发中常见的问题，而内存泄漏往往是罪魁祸首。

>为了简单方便的检测内存泄漏，Square 开源了 [`LeakCanary`](https://github.com/square/leakcanary)，它可以实时监测 Activity 是否发生了泄漏，一旦发现就会自动弹出提示及相关的泄漏信息供分析。

>本文的目的是试图通过分析 `LeakCanary` 源码来探讨它的 Activity 泄漏检测机制。

<!-- more -->

## `LeakCanary` 使用方式
为了将 `LeakCanary` 引入到我们的项目里，我们只需要做以下两步：
```
dependencies {
 debugCompile 'com.squareup.leakcanary:leakcanary-android:1.5.1'
 releaseCompile 'com.squareup.leakcanary:leakcanary-android-no-op:1.5.1'
 testCompile 'com.squareup.leakcanary:leakcanary-android-no-op:1.5.1'
}

public class ExampleApplication extends Application {
  @Override public void onCreate() {
    super.onCreate();
    if (LeakCanary.isInAnalyzerProcess(this)) {
      // This process is dedicated to LeakCanary for heap analysis.
      // You should not init your app in this process.
      return;
    }
    LeakCanary.install(this);
  }
}
```

可以看出，最关键的就是 `LeakCanary.install(this);` 这么一句话，正式开启了 `LeakCanary` 的大门，未来它就会自动帮我们检测内存泄漏，并在发生泄漏是弹出通知信息。

##  从 `LeakCanary.install(this);` 开始
下面我们来看下它做了些什么？
```
  public static RefWatcher install(Application application) {
    return install(application, DisplayLeakService.class,
        AndroidExcludedRefs.createAppDefaults().build());
  }

  public static RefWatcher install(Application application,
      Class<? extends AbstractAnalysisResultService> listenerServiceClass,
      ExcludedRefs excludedRefs) {
    if (isInAnalyzerProcess(application)) {
      return RefWatcher.DISABLED;
    }
    enableDisplayLeakActivity(application);
    HeapDump.Listener heapDumpListener =
        new ServiceHeapDumpListener(application, listenerServiceClass);
    RefWatcher refWatcher = androidWatcher(application, heapDumpListener, excludedRefs);
    ActivityRefWatcher.installOnIcsPlus(application, refWatcher);
    return refWatcher;
  }
```

首先，我们先看最重要的部分，就是：
```
RefWatcher refWatcher = androidWatcher(application, heapDumpListener, excludedRefs);
ActivityRefWatcher.installOnIcsPlus(application, refWatcher);	
```
先生成了一个 `RefWatcher`，这个东西非常关键，从名字可以看出，它是用来 `watch Reference` 的，也就是用来一个监控引用的工具。然后再把 `refWatcher` 和我们自己提供的 `application` 传入到 `ActivityRefWatcher.installOnIcsPlus(application, refWatcher);` 这句里面，继续看。

```
public static void installOnIcsPlus(Application application, RefWatcher refWatcher) {
    ActivityRefWatcher activityRefWatcher = new ActivityRefWatcher(application, refWatcher);
    activityRefWatcher.watchActivities();
}
```

创建了一个 `ActivityRefWatcher`，大家应该能感受到，这个东西就是用来监控我们的 `Activity` 泄漏状况的，它调用`watchActivities()` 方法，就可以开始进行监控了。下面就是它监控的核心原理：

```
public void watchActivities() {
  application.registerActivityLifecycleCallbacks(lifecycleCallbacks);
}
```

它向 `application` 里注册了一个 `ActivitylifecycleCallbacks` 的回调函数，可以用来监听 `Application` 整个生命周期所有 `Activity` 的 lifecycle 事件。再看下这个 `lifecycleCallbacks` 是什么？
```
  private final Application.ActivityLifecycleCallbacks lifecycleCallbacks =
      new Application.ActivityLifecycleCallbacks() {
        @Override public void onActivityCreated(Activity activity, Bundle savedInstanceState) {
        }

        @Override public void onActivityStarted(Activity activity) {
        }

        @Override public void onActivityResumed(Activity activity) {
        }

        @Override public void onActivityPaused(Activity activity) {
        }

        @Override public void onActivityStopped(Activity activity) {
        }

        @Override public void onActivitySaveInstanceState(Activity activity, Bundle outState) {
        }

        @Override public void onActivityDestroyed(Activity activity) {
          ActivityRefWatcher.this.onActivityDestroyed(activity);
        }
      };
```

原来它只监听了所有 `Activity` 的 `onActivityDestroyed` 事件，当 `Activity` 被 `Destory` 时，调用 `ActivityRefWatcher.this.onActivityDestroyed(activity);` 函数。

猜测下，正常情况下，当一个这个函数应该 `activity` 被 `Destory` 时，那这个 `activity` 对象应该变成 null 才是正确的。如果没有变成null，那么就意味着发生了内存泄漏。

因此我们向，这个函数 `ActivityRefWatcher.this.onActivityDestroyed(activity);` 应该是用来监听 `activity` 对象是否变成了 null。继续看。

```
  void onActivityDestroyed(Activity activity) {
    refWatcher.watch(activity);
  }
  RefWatcher refWatcher = androidWatcher(application, heapDumpListener, excludedRefs);
```

可以看出，这个函数把目标 `activity` 对象传给了 `RefWatcher`，让它去监控这个 `activity` 是否被正常回收了，若未被回收，则意味着发生了内存泄漏。

## RefWatcher 如何监控 activity 是否被正常回收呢？
我们先来看看这个 `RefWatcher` 究竟是个什么东西？
```
  public static RefWatcher androidWatcher(Context context, HeapDump.Listener heapDumpListener,
      ExcludedRefs excludedRefs) {
    AndroidHeapDumper heapDumper = new AndroidHeapDumper(context, leakDirectoryProvider);
    heapDumper.cleanup();

    int watchDelayMillis = 5000;
    AndroidWatchExecutor executor = new AndroidWatchExecutor(watchDelayMillis);

    return new RefWatcher(executor, debuggerControl, GcTrigger.DEFAULT, heapDumper,
        heapDumpListener, excludedRefs);
  }
```

这里面涉及到两个新的对象：`AndroidHeapDumper` 和 `AndroidWatchExecutor`，前者用来 dump 堆内存状态的，后者则是用来 watch 一个引用的监听器。具体原理后面再看。总之，这里已经生成好了一个 `RefWatcher` 对象了。

现在再看上面 `onActivityDestroyed(Activity activity)` 里调用的 `refWatcher.watch(activity);`，下面来看下这个最为核心的 `watch(activity)` 方法，了解它是如何监控 `activity` 是否被回收的。

```
  private final Set<String> retainedKeys;
  public void watch(Object activity, String referenceName) {
    String key = UUID.randomUUID().toString();
    retainedKeys.add(key);

    final KeyedWeakReference reference =
        new KeyedWeakReference(activity, key, referenceName, queue);

    watchExecutor.execute(new Runnable() {
      @Override public void run() {
        ensureGone(reference, watchStartNanoTime);
      }
    });
  }

  final class KeyedWeakReference extends WeakReference<Object> {
    public final String key;
    public final String name;
  }
```
可以看到，它首先把我们传入的 `activity` 包装成了一个 `KeyedWeakReference`（可以暂时看成一个普通的 WeakReference），然后 `watchExecutor` 会去执行一个 Runnable，这个 Runnable 会调用 `ensureGone(reference, watchStartNanoTime)` 函数。

看这个函数之前猜测下，我们知道 `watch` 函数本身就是用来监听 `activity` 是否被正常回收，这就涉及到两个问题：

1. 何时去检查它是否回收？
2. 如何有效地检查它真的被回收？

所以我们觉得 `ensureGone` 函数本身要做的事正如它的名字，就是确保 `reference` 被回收掉了，否则就意味着内存泄漏。

#### 核心函数：ensureGone(reference) 检测回收 
下面来看这个函数实现：
```
  void ensureGone(KeyedWeakReference reference, long watchStartNanoTime) {
    removeWeaklyReachableReferences();
    if (gone(reference) || debuggerControl.isDebuggerAttached()) {
      return;
    }
    gcTrigger.runGc();
    removeWeaklyReachableReferences();
    if (!gone(reference)) {
      File heapDumpFile = heapDumper.dumpHeap();
      heapdumpListener.analyze(
          new HeapDump(heapDumpFile, reference.key, reference.name, excludedRefs, watchDurationMs,
              gcDurationMs, heapDumpDurationMs));
    }
  }

  private boolean gone(KeyedWeakReference reference) {
    return !retainedKeys.contains(reference.key);
  }

  private void removeWeaklyReachableReferences() {
    KeyedWeakReference ref;
    while ((ref = (KeyedWeakReference) queue.poll()) != null) {
      retainedKeys.remove(ref.key);
    }
  }
```

这里先来解释下 `WeakReference` 和 `ReferenceQueue` 的工作原理。

1. 弱引用 WeakReference
被强引用的对象就算发生 OOM 也永远不会被垃圾回收机回收；被弱引用的对象，只要被垃圾回收器发现就会立即被回收；被软引用的对象，具备内存敏感性，只有内存不足时才会被回收，常用来做内存敏感缓存器；虚引用则任意时刻都可能被回收，使用较少。
2. 引用队列 ReferenceQueue
我们常用一个 `WeakReference<Activity> reference = new WeakReference(activity);`，这里我们创建了一个 `reference` 来弱引用到某个 `activity`，当这个 `activity` 被垃圾回收器回收后，这个 `reference` 会被放入内部的 `ReferenceQueue` 中。也就是说，从队列 `ReferenceQueue` 取出来的所有 `reference`，它们指向的真实对象都已经成功被回收了。

然后再回到上面的代码。

在一个 activity 传给 RefWatcher 时会创建一个唯一的 key 对应这个 activity，该key存入一个集合 `retainedKeys` 中。也就是说，所有我们想要观测的 `activity` 对应的唯一 key 都会被放入 `retainedKeys` 集合中。

基于我们对 `ReferenceQueue` 的了解，只要把队列中所有的 reference 取出来，并把对应 retainedKeys 里的key移除，剩下的 key 对应的对象都没有被回收。

1. ensureGone 首先调用 `removeWeaklyReachableReferences` 把已被回收的对象的 key 从 retainedKeys 移除，剩下的 key 都是未被回收的对象；
2. if (gone(reference)) 用来判断某个 reference 的key是否仍在 retainedKeys 里，若不在，表示已回收，否则继续；
3. gcTrigger.runGc(); 手动出发 GC，立即把所有 WeakReference 引用的对象回收；
4. removeWeaklyReachableReferences(); 再次清理 retainedKeys，如果该 reference 还在 retainedKeys里 (if (!gone(reference)))，表示泄漏；
5. 利用 heapDumper 把内存情况 dump 成文件，并调用 heapdumpListener 进行内存分析，进一步确认是否发生内存泄漏。
6. 如果确认发生内存泄漏，调用 `DisplayLeakService` 发送通知。

至此，核心的内存泄漏检测机制便看完了。

## 内存泄漏检测小结
从上面我们大概了解了内存泄漏检测机制，大概是以下几个步骤：
1. 利用 `application.registerActivityLifecycleCallbacks(lifecycleCallbacks)` 来监听整个生命周期内的 Activity `onDestoryed` 事件;
2. 当某个 `Activity` 被 destory 后，将它传给 RefWatcher 去做观测，确保其后续会被正常回收；
3. RefWatcher 首先把 `Activity` 使用 KeyedWeakReference 引用起来，并使用一个 ReferenceQueue 来记录该 KeyedWeakReference 指向的对象是否已被回收；
4. `AndroidWatchExecutor` 会在 5s 后，开始检查这个弱引用内的 `Activity` 是否被正常回收。判断条件是：若 `Activity` 被正常回收，那么引用它的 KeyedWeakReference 会被自动放入 ReferenceQueue 中。
5. 判断方式是：先看 `Activity` 对应的 `KeyedWeakReference` 是否已经放入 `ReferenceQueue` 中；如果没有，则手动GC：`gcTrigger.runGc();`；然后再一次判断 `ReferenceQueue` 是否已经含有对应的 `KeyedWeakReference`。若还未被回收，则认为可能发生内存泄漏。
6. 利用 HeapAnalyzer 对 dump 的内存情况进行分析并进一步确认，若确定发生泄漏，则利用 `DisplayLeakService` 发送通知。

## 探讨一些关于 `LeakCanary` 有趣的问题
在学习了 `LeakCanary` 的源码之后，我想再提几个有趣的问题做些探讨。

### `LeakCanary` 项目目录结构为什么这样分？
下面是整个 `LeakCanary` 的项目结构：
![](/img/leakcanary/project.png)

对于开发者而言，只需要使用到 `LeakCanary.install(this);` 这一句即可。那整个项目为什么要分成这么多个 module 呢？

实际上，这里面每一个 module 都有自己的角色。

- `leakcanary-watcher`: 这是一个通用的内存检测器，对外提供一个 RefWatcher#watch(Object watchedReference)，可以看出，它不仅能够检测 `Activity`，还能监测任意常规的 Java Object 的泄漏情况。

- `leakcanary-android`: 这个 module 是与 `Android` 世界的接入点，用来专门监测 `Activity` 的泄漏情况，内部使用了 application#registerActivityLifecycleCallbacks 方法来监听 onDestory 事件，然后利用 `leakcanary-watcher` 来进行弱引用＋手动 GC 机制进行监控。

- `leakcanary-analyzer`: 这个 module 提供了 `HeapAnalyzer`，用来对 dump 出来的内存进行分析并返回内存分析结果 `AnalysisResult`，内部包含了泄漏发生的路径等信息供开发者寻找定位。

- `leakcanary-android-no-op`: 这个 module 是专门给 release 的版本用的，内部只提供了两个完全空白的类 `LeakCanary` 和 `RefWatcher`，这两个类不会做任何内存泄漏相关的分析。为什么？因为 `LeakCanary` 本身会由于不断 gc 影响到 app 本身的运行，而且主要用于开发阶段的内存泄漏检测。因此对于 release 则可以 disable 所有泄漏分析。

- `leakcanary-sample`: 这个很简单，就是提供了一个用法 sample。

### 当 Activity 被 destory 后，LeakCanary 多久后会去进行检查其是否泄漏呢？
在源码中可以看到，LeakCanary 并不会在 destory 后立即去检查，而是让一个 `AndroidWatchExecutor` 去进行检查。它会做什么呢？
```
  @Override public void execute(final Runnable command) {
    if (isOnMainThread()) {
      executeDelayedAfterIdleUnsafe(command);
    } else {
      mainHandler.post(new Runnable() {
        @Override public void run() {
          executeDelayedAfterIdleUnsafe(command);
        }
      });
    }
  }

  void executeDelayedAfterIdleUnsafe(final Runnable runnable) {
    // This needs to be called from the main thread.
    Looper.myQueue().addIdleHandler(new MessageQueue.IdleHandler() {
      @Override public boolean queueIdle() {
        backgroundHandler.postDelayed(runnable, delayMillis);
        return false;
      }
    });
  }
```

可以看到，它首先会向主线程的 MessageQueue 添加一个 `IdleHandler`。

什么是 `IdleHandler`？我们知道 Looper 会不断从 MessageQueue 里取出 Message 并执行。当没有新的 Message 执行时，Looper 进入 Idle 状态时，就会取出 `IdleHandler` 来执行。

换句话说，`IdleHandler`就是`优先级别较低的 Message`，只有当 Looper 没有消息要处理时才得到处理。而且，内部的 `queueIdle()` 方法若返回 `true`，表示该任务一直存活，每次 Looper 进入 Idle 时就执行；反正，如果返回 `false`，则表示只会执行一次，执行完后丢弃。

那么，这件优先级较低的任务是什么呢？`backgroundHandler.postDelayed(runnable, delayMillis);`，runnable 就是之前 `ensureGone()`。

也就是说，当主线程空闲了，没事做了，开始向后台线程发送一个延时消息，告诉后台线程，5s(delayMillis)后开始检查 `Activity` 是否被回收了。

所以，当 `Activity` 发生 `destory` 后，首先要等到主线程空闲，然后再延时 5s(delayMillis)，才开始执行泄漏检查。

##### 知识点：
1. 如何创建一个优先级低的主线程任务，它只会在主线程空闲时才执行，不会影响到app的性能？
```
Looper.myQueue().addIdleHandler(new MessageQueue.IdleHandler() {
      @Override public boolean queueIdle() {
        // do task
        return false; // only once
      }
    });
```
2. 如何快速创建一个主／子线程handler？
```
//主线程handler
mainHandler = new Handler(Looper.getMainLooper());

//子线程handler
HandlerThread handlerThread = new HandlerThread(“子线程任务”);
handlerThread.start();
Handler backgroundHandler = new Handler(handlerThread.getLooper());
```
3. 如何快速判断当前是否运行在主线程？
```
Looper.getMainLooper().getThread() == Thread.currentThread();
```

### System.gc() 可以触发立即 gc 吗？如果不行那怎么才能触发即时 gc 呢？
在 LeakCanary 里，需要立即触发 gc，并在之后立即判断弱引用是否被回收。这意味着该 gc 必须能够立即同步执行。

常用的触发 gc 方法是 `System.gc()`，那它能达到我们的要求吗？

我们来看下其实现方式：
```
    /**
     * Indicates to the VM that it would be a good time to run the
     * garbage collector. Note that this is a hint only. There is no guarantee
     * that the garbage collector will actually be run.
     */
    public static void gc() {
        boolean shouldRunGC;
        synchronized(lock) {
            shouldRunGC = justRanFinalization;
            if (shouldRunGC) {
                justRanFinalization = false;
            } else {
                runGC = true;
            }
        }
        if (shouldRunGC) {
            Runtime.getRuntime().gc();
        }
    }
```

注释里清楚说了，`System.gc()`只是建议垃圾回收器来执行回收，但是`不能保证真的去回收`。从代码也能看出，必须先判断 `shouldRunGC` 才能决定是否真的要 gc。

##### 知识点：
那要怎么实现 即时 GC 呢？

`LeakCanary` 参考了一段 [AOSP 的代码](https://android.googlesource.com/platform/libcore/+/master/support/src/test/java/libcore/java/lang/ref/FinalizationTester.java)
```
// System.gc() does not garbage collect every time. Runtime.gc() is
// more likely to perfom a gc.
Runtime.getRuntime().gc();
enqueueReferences();
System.runFinalization();
public static void enqueueReferences() {
    /*
     * Hack. We don't have a programmatic way to wait for the reference queue
     * daemon to move references to the appropriate queues.
     */
    try {
        Thread.sleep(100);
    } catch (InterruptedException e) {
        throw new AssertionError();
    }
}
```

### 可以怎样来改造 LeakCanary 呢？
##### 忽略某些已知泄漏的类或Activity
LeakCanary 提供了 ExcludedRefs 类，可以向里面添加某些主动忽略的类。比如已知 Android 源代码里有某些内存泄漏，不属于我们 App 的泄漏，那么就可以 exclude 掉。

另外，如果不想监控某些特殊的 Activity，那么可以在 `onActivityDestroyed(Activity activity)` 里，过滤掉特殊的 Activity，只对其它 Activity 调用 `refWatcher.watch(activity)` 监控。

##### 把内存泄漏数据上传至服务器
在 LeakCanary 提供了 `AbstractAnalysisResultService`，它是一个 intentService，接收到的 intent 内包含了 `HeapDump` 数据和 `AnalysisResult` 结果，我们只要继承这个类，实现自己的 `listenerServiceClass`，就可以将堆数据和分析结果上传到我们自己的服务器上。

## 小结
本文通过源代码分析了 LeakCanary 的原理，并提出了一些有趣的问题，学习了一些实用的知识点。希望对读者有所启发，欢迎与我讨论。

之后会继续挑选优质开源项目进行分析，欢迎提意见。

谢谢。

wingjay

http://wingjay.com

![](https://avatars0.githubusercontent.com/u/9619875?v=3&s=460)





