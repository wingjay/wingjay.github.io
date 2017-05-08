title: Java 技术之类加载机制
date: 2017-05-08 20:46:38
permalink: java_classloader
categories:
  - 深入理解Java技术
tags:
  - Java
  - Annotation
---
> 类加载机制是 Java 语言的一大亮点，使得 Java 类可以被动态加载到 Java 虚拟机中。

> 这次我们抛开术语和概念，从例子入手，由浅入深地讲解 Java 的类加载机制。

> 本文涉及知识点：双亲委托机制、BootstrapClassLoader、ExtClassLoader、AppClassLoader、自定义网络类加载器等

> 文章涉及代码：https://github.com/wingjay/HelloJava/blob/master/common/src/classloader/HelloClassLoader.java

<!-- more -->

## 什么是 Java 类加载机制?
Java 虚拟机一般使用 Java 类的流程为：首先将开发者编写的 Java 源代码（.java文件）编译成 Java 字节码（.class文件），然后类加载器会读取这个 .class 文件，并转换成 java.lang.Class 的实例。有了该 Class 实例后，Java 虚拟机可以利用 newInstance 之类的方法创建其真正对象了。

ClassLoader 是 Java 提供的类加载器，绝大多数的类加载器都继承自 ClassLoader，它们被用来加载不同来源的 Class 文件。

## Class 文件有哪些来源呢?
上文提到了 ClassLoader 可以去加载多种来源的 Class，那么具体有哪些来源呢？

首先，最常见的是开发者在应用程序中编写的类，这些类位于项目目录下；

然后，有 Java 内部自带的`核心类`如 `java.lang`、`java.math`、`java.io` 等 package 内部的类，位于 `$JAVA_HOME/jre/lib/` 目录下，如 `java.lang.String` 类就是定义在 `$JAVA_HOME/jre/lib/rt.jar` 文件里；

另外，还有 Java `核心扩展类`，位于 `$JAVA_HOME/jre/lib/ext` 目录下。开发者也可以把自己编写的类打包成 jar 文件放入该目录下；

最后还有一种，是动态加载远程的 .class 文件。

既然有这么多种类的来源，那么在 Java 里，是由某一个具体的 ClassLoader 来统一加载呢？还是由多个 ClassLoader 来协作加载呢？

## 哪些 ClassLoader 负责加载上面几类 Class？
实际上，针对上面四种来源的类，分别有不同的加载器负责加载。

首先，我们来看级别最高的 `Java 核心类`，即`$JAVA_HOME/jre/lib` 里的核心 jar 文件。这些类是 Java 运行的基础类，由一个名为 `BootstrapClassLoader` 加载器负责加载，它也被称作 `根加载器／引导加载器`。注意，`BootstrapClassLoader` 比较特殊，它不继承 `ClassLoader`，而是由 JVM 内部实现；

然后，需要加载 `Java 核心扩展类`，即 `$JAVA_HOME/jre/lib/ext` 目录下的 jar 文件。这些文件由 `ExtensionClassLoader` 负责加载，它也被称作 `扩展类加载器`。当然，用户如果把自己开发的 jar 文件放在这个目录，也会被 `ExtClassLoader` 加载；

接下来是开发者在项目中编写的类，这些文件将由 `AppClassLoader` 加载器进行加载，它也被称作 `系统类加载器 System ClassLoader`；

最后，如果想远程加载如（本地文件／网络下载）的方式，则必须要自己自定义一个 ClassLoader，复写其中的 `findClass()` 方法才能得以实现。

因此能看出，Java 里提供了至少四类 `ClassLoader` 来分别加载不同来源的 Class。

那么，这几种 ClassLoader 是如何协作来加载一个类呢？

## 这些 ClassLoader 以何种方式来协作加载 String 类呢？
String 类是 Java 自带的最常用的一个类，现在的问题是，JVM 将以何种方式把 String class 加载进来呢？

我们来猜想下。

首先，String 类属于 Java 核心类，位于 `$JAVA_HOME/jre/lib` 目录下。有的朋友会马上反应过来，上文中提过了，该目录下的类会由 `BootstrapClassLoader` 进行加载。没错，它确实是由 `BootstrapClassLoader` 进行加载。但，这种回答的前提是你已经知道了 String 在 `$JAVA_HOME/jre/lib` 目录下。

那么，如果你并不知道 String 类究竟位于哪呢？或者我希望你去加载一个 `unknown` 的类呢？

有的朋友这时会说，那很简单，只要去遍历一遍所有的类，看看这个 `unknown` 的类位于哪里，然后再用对应的加载器去加载。

是的，思路很正确。那应该如何去遍历呢？

比如，可以先遍历用户自己写的类，如果找到了就用 `AppClassLoader` 去加载；否则去遍历 Java 核心类目录，找到了就用 `BootstrapClassLoader` 去加载，否则就去遍历 Java 扩展类库，依次类推。

这种思路方向是正确的，不过存在一个漏洞。

假如开发者自己伪造了一个 `java.lang.String` 类，即在项目中创建一个包`java.lang`，包内创建一个名为 `String` 的类，这完全可以做到。那如果利用上面的遍历方法，是不是这个项目中用到的 String 不是都变成了这个伪造的 `java.lang.String` 类吗？如何解决这个问题呢？

解决方法很简单，当查找一个类时，优先遍历最高级别的 Java 核心类，然后再去遍历 Java 核心扩展类，最后再遍历用户自定义类，而且这个遍历过程是一旦找到就立即停止遍历。

在 Java 中，这种实现方式也称作 `双亲委托`。其实很简单，把 `BootstrapClassLoader` 想象为核心高层领导人， `ExtClassLoader` 想象为中层干部， `AppClassLoader` 想象为普通公务员。每次需要加载一个类，先获取一个系统加载器 `AppClassLoader` 的实例（ClassLoader.getSystemClassLoader()），然后向上级层层请求，由最上级优先去加载，如果上级觉得这些类不属于核心类，就可以下放到各子级负责人去自行加载。

如下图所示：
![双亲委托](/img/classloader/order.png)

## 真的是按照`双亲委托`方式进行类加载吗？
下面通过几个例子来验证上面的加载方式。

#### 开发者自定义的类会被 `AppClassLoader` 加载吗？
在项目中创建一个名为 `MusicPlayer` 的类文件，内容如下：
```
package classloader;

public class MusicPlayer {
	public void print() {
		System.out.printf("Hi I'm MusicPlayer");
	}
}
```

然后来加载 `MusicPlayer`。

```
private static void loadClass() throws ClassNotFoundException {
    Class<?> clazz = Class.forName("classloader.MusicPlayer");
    ClassLoader classLoader = clazz.getClassLoader();
    System.out.printf("ClassLoader is %s", classLoader.getClass().getSimpleName());
}
```
打印结果为：
```
ClassLoader is AppClassLoader
```
可以验证，`MusicPlayer` 是由 `AppClassLoader` 进行的加载。

#### 验证 `AppClassLoader` 的双亲真的是 ExtClassLoader 和 BootstrapClassLoader 吗？
这时发现 `AppClassLoader` 提供了一个 `getParent()` 的方法，来打印看看都是什么。
```
private static void printParent() throws ClassNotFoundException {
        Class<?> clazz = Class.forName("classloader.MusicPlayer");
        ClassLoader classLoader = clazz.getClassLoader();
        System.out.printf("currentClassLoader is %s\n", classLoader.getClass().getSimpleName());

        while (classLoader.getParent() != null) {
            classLoader = classLoader.getParent();
            System.out.printf("Parent is %s\n", classLoader.getClass().getSimpleName());
        }
}
```
打印结果为：
```
currentClassLoader is AppClassLoader
Parent is ExtClassLoader
```
首先能看到 `ExtClassLoader` 确实是 `AppClassLoader` 的双亲，不过却没有看到 `BootstrapClassLoader`。事实上，上文就提过， `BootstrapClassLoader`比较特殊，它是由 JVM 内部实现的，所以 `ExtClassLoader.getParent() = null`。

#### 如果把 MusicPlayer 类挪到 `$JAVA_HOME/jre/lib/ext` 目录下会发生什么？
上文中说了，`ExtClassLoader` 会加载`$JAVA_HOME/jre/lib/ext` 目录下所有的 jar 文件。那来尝试下直接把 `MusicPlayer` 这个类放到 `$JAVA_HOME/jre/lib/ext` 目录下吧。

利用下面命令可以把 MusicPlayer.java 编译打包成 jar 文件，并放置到对应目录。
```
javac classloader/MusicPlayer.java
jar cvf MusicPlayer.jar classloader/MusicPlayer.class
mv MusicPlayer.jar $JAVA_HOME/jre/lib/ext/
```

这时 MusicPlayer.jar 已经被放置与 `$JAVA_HOME/jre/lib/ext` 目录下，同时把之前的 `MusicPlayer` `删除`，而且这一次`刻意`使用 `AppClassLoader` 来加载：
```
private static void loadClass() throws ClassNotFoundException {
    ClassLoader appClassLoader = ClassLoader.getSystemClassLoader(); // AppClassLoader
    Class<?> clazz = appClassLoader.loadClass("classloader.MusicPlayer");
    ClassLoader classLoader = clazz.getClassLoader();
    System.out.printf("ClassLoader is %s", classLoader.getClass().getSimpleName());
}
```
打印结果为：
```
ClassLoader is ExtClassLoader
```
说明即使直接用 `AppClassLoader` 去加载，它仍然会被 `ExtClassLoader` 加载到。

## 从源码角度真正理解`双亲委托`加载机制
上面已经通过一些例子了解了`双亲委托`的一些特性了，下面来看一下它的实现代码，加深理解。

打开 `ClassLoader` 里的 `loadClass()` 方法，便是需要分析的源码了。这个方法里做了下面几件事：

1. 检查目标class是否曾经加载过，如果加载过则直接返回；
2. 如果没加载过，把加载请求传递给 parent 加载器去加载；
3. 如果 parent 加载器加载成功，则直接返回；
4. 如果 parent 未加载到，则自身调用 findClass() 方法进行寻找，并把寻找结果返回。

代码如下：
```
protected Class<?> loadClass(String name, boolean resolve)
    throws ClassNotFoundException
{
    synchronized (getClassLoadingLock(name)) {
        // 1. 检查是否曾加载过
        Class<?> c = findLoadedClass(name);
        if (c == null) {
            long t0 = System.nanoTime();
            try {
                if (parent != null) {
                	// 优先让 parent 加载器去加载
                    c = parent.loadClass(name, false);
                } else {
                	// 如无 parent，表示当前是 BootstrapClassLoader，调用 native 方法去 JVM 加载
                    c = findBootstrapClassOrNull(name);
                }
            } catch (ClassNotFoundException e) {
                // ClassNotFoundException thrown if class not found
                // from the non-null parent class loader
            }

            if (c == null) {
            	// 如果 parent 均没有加载到目标class，调用自身的 findClass() 方法去搜索
                long t1 = System.nanoTime();
                c = findClass(name);

                // this is the defining class loader; record the stats
                sun.misc.PerfCounter.getParentDelegationTime().addTime(t1 - t0);
                sun.misc.PerfCounter.getFindClassTime().addElapsedTimeFrom(t1);
                sun.misc.PerfCounter.getFindClasses().increment();
            }
        }
        if (resolve) {
            resolveClass(c);
        }
        return c;
    }
}

// BootstrapClassLoader 会调用 native 方法去 JVM 加载
private native Class<?> findBootstrapClass(String name);
```

看完实现源码相信能够有更完整的理解。

## 类加载器最酷的一面：自定义类加载器
前面提到了 Java 自带的加载器 `BootstrapClassLoader`、`AppClassLoader`和`ExtClassLoader`，这些都是 Java 已经提供好的。

而真正有意思的，是 `自定义类加载器`，它允许我们在`运行时`可以从`本地磁盘或网络`上动态加载自定义类。这使得开发者可以动态修复某些有问题的类，热更新代码。

下面来实现一个`网络类加载器`，这个加载器可以从网络上动态下载 .class 文件并加载到虚拟机中使用。

后面我还会写作与 `热修复／动态更新` 相关的文章，这里先学习 Java 层 `NetworkClassLoader` 相关的原理。

1. 作为一个 `NetworkClassLoader`，它首先要继承 `ClassLoader`；
2. 然后它要实现`ClassLoader`内的 `findClass()` 方法。注意，不是`loadClass()`方法，因为`ClassLoader`提供了`loadClass()`（如上面的源码），它会基于`双亲委托`机制去搜索某个 class，直到搜索不到才会调用自身的`findClass()`，如果直接复写`loadClass()`，那还要实现`双亲委托`机制；
3. 在 `findClass()` 方法里，要从网络上下载一个 .class 文件，然后转化成 Class 对象供虚拟机使用。

具体实现代码如下：
```
/**
 * Load class from network
 */
public class NetworkClassLoader extends ClassLoader {

    @Override
    protected Class<?> findClass(String name) throws ClassNotFoundException {
        byte[] classData = downloadClassData(name); // 从远程下载
        if (classData == null) {
            super.findClass(name); // 未找到，抛异常
        } else {
            return defineClass(name, classData, 0, classData.length); // convert class byte data to Class<?> object
        }
        return null;
    }

    private byte[] downloadClassData(String name) {
        // 从 localhost 下载 .class 文件
        String path = "http://localhost" + File.separatorChar + "java" + File.separatorChar + name.replace('.', File.separatorChar) + ".class"; 

        try {
            URL url = new URL(path);
            InputStream ins = url.openStream();
            ByteArrayOutputStream baos = new ByteArrayOutputStream();
            int bufferSize = 4096;
            byte[] buffer = new byte[bufferSize];
            int bytesNumRead = 0;
            while ((bytesNumRead = ins.read(buffer)) != -1) {
                baos.write(buffer, 0, bytesNumRead); // 把下载的二进制数据存入 ByteArrayOutputStream
            }
            return baos.toByteArray();
        } catch (Exception e) {
            e.printStackTrace();
        }
        return null;
    }

    public String getName() {
        System.out.printf("Real NetworkClassLoader\n");
        return "networkClassLoader";
    }
}
```

这个类的作用是从网络上（这里是本人的 local apache 服务器 http://localhost/java 上）目录里去下载对应的 .class 文件，并转换成 Class<?> 返回回去使用。

下面我们来利用这个 `NetworkClassLoader` 去加载 localhost 上的 `MusicPlayer` 类：

1. 首先把 `MusicPlayer.class` 放置于 `/Library/WebServer/Documents/java` （MacOS）目录下，由于 MacOS 自带 apache 服务器，这里是服务器的默认目录；
2. 执行下面一段代码：
```
String className = "classloader.NetworkClass";
NetworkClassLoader networkClassLoader = new NetworkClassLoader();
Class<?> clazz  = networkClassLoader.loadClass(className);
```
3. 正常运行，加载 `http://localhost/java/classloader/MusicPlayer.class`成功。

可以看出 `NetworkClassLoader` 可以正常工作，如果读者要用的话，只要稍微修改 url 的拼接方式即可自行使用。

## 小结
类加载方式是 Java 上非常创新的一项技术，给未来的热修复技术提供了可能。本文力求通过简单的语言和合适的例子来讲解其中`双亲委托机制`、`自定义加载器`等，并开发了自定义的`NetworkClassLoader`。

当然，类加载是很有意思的技术，很难覆盖所有知识点，比如不同类加载器加载同一个类，得到的实例却不是同一个等等。

之后我还会写作关于热修复／动态更新相关的技术，欢迎关注。

谢谢。

wingjay

http://wingjay.com

![](https://avatars0.githubusercontent.com/u/9619875?v=3&s=460)


