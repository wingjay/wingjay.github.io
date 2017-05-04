title: Java 技术之反射
date: 2017-04-26 22:37:55
tags: Java
---
>关于Java反射机制的文章很多，这次换种方式来讲解反射的作用。

>本文涉及到的知识点：`class.getDeclaredXXX()`、`XXX.getModifiers()`、`method.getReturnType()`、`method.getParameterTypes()`、`method.isAnnotationPresent(XXX.class)`、`Modifier.isStatic(method.getModifiers())` 和 `constructor.newInstance(XX)`

>本文涉及代码：https://github.com/wingjay/HelloJava/blob/master/data-structure/src/reflection/ForArticle.java   

<!-- more -->

## 先来看一个熟悉的 Class
首先，简单来说，反射就是在运行时可以获取任意 `Class` 或 `Object` 内部所有成员属性，如成员变量、成员方法、构造函数和 Annotation。

这次先给出一个大家非常熟悉的 `Class`：`UserBean`。

本文要完成的任务就是，在只有一个 `UserBean.getClass()` 的情况下，利用代码`打印出其内部所有成员变量、方法，并动态执行内部用 @Invoke 修饰的成员方法`。

```
package com.wingjay.reflection;

public class UserBean {

    public String userName;

    private long userId;

    public UserBean(String userName, long userId) {
        this.userName = userName;
        this.userId = userId;
    }

    public String getName() {
        return userName;
    }

    public long getId() {
        return userId;
    }

    @Invoke
    public static void staticMethod(String devName) {
        System.out.printf("Hi %s, I'm a static method", devName);
    }

    @Invoke
    public void publicMethod() {
        System.out.println("I'm a public method");
    }

    @Invoke
    private void privateMethod() {
        System.out.println("I'm a private method");
    }
}
```

在只提供一个 UserBean 的 Class 情况下，

1. 打印出这个 `Class` 内部的所有成员变量、成员方法、构造函数，包括 `private` 的；
2. 调用这个 `Class` 内部的三个用 `@Invoke` 修饰的方法：`staticMethod()`, `publicMethod()`, `privateMethod()`；

## 1. 打印 UserBean Class 里的所有成员变量、成员方法，包括 private 的
首先我们拥有一个 `Class userBeanClass = UserBean.class`，我们要利用这个 `Class` 来打印它的成员变量 `userName` 和 `userId`。

#### 打印成员变量
那么如何获取成员变量呢，我们发现，Java 里提供了 `Field` 这个类来表示成员变量，提供了 `clazz.getDeclaredFields()` 来获取一个类内部声明的所有变量。因此，可以利用下面的代码获取 `userBeanClass` 内部所有的成员变量。
```
Field[] fields = userBeanClass.getDeclaredFields();
```
那么，我们如何将一个 `field` 对象打印成 `private String userName;` 这种形式呢？或者说如何分别找到 `private`、`String`、`userName` 这三个值呢？

其实，`Field` 里包含了三种元素来对应它们，分别是`Modifier`、`Type`、`Name`。
```
private <-- field.getModifiers();
String <-- field.getType();
userName <-- field.getName();
```

```
// fields
Field[] fields = userBeanClass.getDeclaredFields();

for(Field field : fields) {
    String fieldString = "";
    fieldString += Modifier.toString(field.getModifiers()) + " "; // `private`
    fieldString += field.getType().getSimpleName() + " "; // `String`
    fieldString += field.getName(); // `userName`
    fieldString += ";";
    System.out.println(fieldString);
}
```

打印结果：

```
public String userName;
private long userId;
```

#### 打印成员方法
类似成员变量的 `Field`，成员方法也有对应的类 `Method`，首先可以通过 `Method[] methods = userBeanClass.getDeclaredMethods();` 获得所有的成员方法，然后，为了打印形如：`public static void staticMethod(String devName)`的数据，可以利用下列 `method` 提供的方法：

```
private static <-- method.getModifiers();
void <-- method.getReturnType();
staticMethod <-- method.getName();
String <-- method.getParameterTypes();
```

因此可以得到:
```
Method[] methods = userBeanClass.getDeclaredMethods();
for (Method method : methods) {
    String methodString = Modifier.toString(method.getModifiers()) + " " ; // private static
    methodString += method.getReturnType().getSimpleName() + " "; // void
    methodString += method.getName() + "("; // staticMethod 
    Class[] parameters = method.getParameterTypes();
    for (Class parameter : parameters) {
        methodString += parameter.getSimpleName() + " "; // String
    }
    methodString += ")";
    System.out.println(methodString);
}
```

打印结果如下：
```
public String getName()
public long getId()
public static void staticMethod(String )
public void publicMethod()
private void privateMethod()
```
可以完整的打印所有成员方法，无论是 `public` 还是 `private`，而且能打印 `static` 关键字。

#### 打印构造函数
其实构造函数和成员函数非常类似，Java 里提供了 `Constructor` 来表示构造函数，为了打印 `public UserBean(String userName, long userId)`，可以利用下面的函数实现：

```
// constructors
Constructor[] constructors = userBeanClass.getDeclaredConstructors();
for (Constructor constructor : constructors) {
    String s = Modifier.toString(constructor.getModifiers()) + " ";
    s += constructor.getName() + "(";
    Class[] parameters = constructor.getParameterTypes();
    for (Class parameter : parameters) {
        s += parameter.getSimpleName() + ", ";
    }
    s += ")";
    System.out.println(s);
}
```

打印结果如下：
```
public com.wingjay.reflection.UserBean(String, long)
```

## 2. 调用 Class 内部的用 `@Invoke` 修饰的方法
从上面知道，我们可以利用 `class.getDeclaredMethods()` 获取一个类内部所有成员方法，接下来我们还要做的事是：

1. 判断这个方法是否被 `@Invoke` 修饰
2. 如果修饰，判断这个方法是不是 `static` 的
3. 如果是 `static`，则可以直接用 class 调用
4. 如果不是 `static`，那就需要实例化一个对象来调用
5. 如果这个方法是 `private` 的，要记得 `setAccessible(true)`。

如果分别实现上面的一些功能呢？

- 为了判断一个 Method 是否被某个 Annotation 修饰，可以用 `method.isAnnotationPresent(Invoke.class)` ；
- 关于 `static` `private`，我们可以用 `Modifier` 类提供的 `Modifier.isStatic()` 和 `Modifier.isPrivate()`来判断；
- 如果 Method 不是 static，那就要实例化对象，我们可以用 `class.newInstance()` 或者 `constructor.newInstance(params)` 来得到实例。
- 关于执行一个 Method，可以使用 `method.invoke(object, ...params)` 方法，如果方法不是 `static` 就必须实例化一个 `object` 传给它，否则可以传 `null`


实现如下：
```
Method[] methods = userBeanClass.getDeclaredMethods(); // 获取所有成员方法
for (Method method : methods) {
    if (method.isAnnotationPresent(Invoke.class)) { // 判断是否被 @Invoke 修饰
        if (Modifier.isStatic(method.getModifiers())) { // 如果是 static 方法
            method.invoke(null, "wingjay"); // 直接调用，并传入需要的参数 devName
        } else {
            Class[] params = {String.class, long.class};
            Constructor constructor = userBeanClass.getDeclaredConstructor(params); // 获取参数格式为 String,long 的构造函数
            Object userBean = constructor.newInstance("wingjay", 11); // 利用构造函数进行实例化，得到 Object
            if (Modifier.isPrivate(method.getModifiers())) {
                method.setAccessible(true); // 如果是 private 的方法，需要获取其调用权限
            }
            method.invoke(userBean); // 调用 method，无须参数
        }
    }
}
```

打印结果：
```
I'm a public method
Hi wingjay, I'm a static method
I'm a private method
```

可见三个方法都正常调用了，而且 `public static void staticMethod(String devName)` 的参数 `devName` 也正常传进去了。

## 小结
基于上面两个实践，我们已经能够利用反射机制，在运行状态下把一个 Class 的内部成员方法、成员变量和构造函数全部获取到，并且能够进行实例化、直接调用内部的成员方法。

因此，有了反射机制，我们即使只有动态得到的 Class，也能直接得到它内部的信息、甚至调用它内部的方法。

了解了反射后，下文我将介绍 `Annotation` 一些有趣的自定义实现，合理地利用 `Annotation` 能让代码更简洁，自动生成代码，实现一些常规难以实现的功能。

谢谢。

wingjay


[我的Github](https://github.com/wingjay): <https://github.com/wingjay> 
[微博 iam_wingjay](http://weibo.com/u/1625892654): <http://weibo.com/u/1625892654>

如果有问题，可以给我留言或发邮件<mailto:yinjiesh@126.com>

![](https://avatars0.githubusercontent.com/u/9619875?v=3&s=460)
