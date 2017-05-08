title: Java 技术之注解 Annotation
date: 2017-05-03 10:47:11
categories:
  - 深入理解Java技术
tags: 
  - Java
  - Annotation
---

>`注解`这种语法本身很有意思，当前很多流行库如 `Dagger`、`ButterKnife`等都是基于注解这种语法。

>熟练使用`注解`，既能让你的代码变得简洁易读，动态运行时执行你想要的操作，还能帮你生成代码，省去重复代码写作。

> 本文涉及知识点：注解的生命周期，代码编辑时注解，编译时注解代码生成，运行时注解动态反射。

<!-- more -->


## 注解的生命周期与修饰对象
对于 Java 代码从编写到运行有三个时期：代码编辑；编译成 `.class` 文件；读取到 JVM 运行。针对这三个时期有三种 `Annotation` 对应：
```
RetentionPolicy.SOURCE  // 只在代码编辑期生效

RetentionPolicy.CLASS  // 在编译期生效，默认值

RetentionPolicy.RUNTIME // 在代码运行时生效
```

除了生命周期，我们还可以指定 `Annotation` 用来指定的对象，比如修饰方法、类、变量、参数等，例如：
```
@Annotation 
public void getName() {}

@Annotation 
String name;

public void setName(@Annotation String name) {}
```

Java 提供了 `@Target` 这个`元注解`来指定某个 `Annotation` 修饰的目标对象。

例如 `@Override` 是用来修饰方法的。
```
@Target(ElementType.METHOD)
public @interface Override {
}
```

而 `@SuppressWarnings` 可以用来修饰很多，包括类、方法、变量等等。
```
@Target({TYPE, FIELD, METHOD, PARAMETER, CONSTRUCTOR, LOCAL_VARIABLE})
public @interface SuppressWarnings {
    String[] value();
}
```

下面我们依次来看看不同生命周期的三类 Annotation。

## 1. 代码编辑时注解
这种 Annotation 只存在于代码编辑阶段（RetentionPolicy.SOURCE），主要功能是让 IDE 来为开发者提供 warning 检查。这一类注解只会在编辑代码时生效，当编译器把 .java 文件编译成 .class 文件时会自动丢弃。

比较常用的有 `SuppressWarnings`，`Override`。

`SuppressWarnings`是抑制编译器生成警告信息，比如我们调用了某个被标记为 `Deprecated` 的方法，这时编译器会发出警告，而我们又不得不使用这个方法时，就可以用`@SuppressWarnings`来抑制这个警告。
```
@Retention(RetentionPolicy.SOURCE)
public @interface SuppressWarnings {
    String[] value();
}
```
其作用如下图，`@SuppressWarnings("deprecation")` 可以把 `deprecation` 相关的警告给抑制掉。


![warning](/img/annotation/warning.png)
![no-warning](/img/annotation/no-warning.png)

`Override`用来标记重写父类某个方法，万一不小心写错方法名或者父类该方法发生改动，IDE 就会发出警告。
```
@Retention(RetentionPolicy.SOURCE)
public @interface Override {
}
```

当然，对于开发者而言，这一类的 Annotation 我们很少自定义，更重要的是学会使用。其实 Java 和 Android 里提供了非常多有用的静态检查的 Annotation，有助于提高代码的正确率，省去人工的代码检查，方便代码给他人使用。

之后的文章我会具体介绍 Android 内部[`support-annotations`]很多有趣有用的 Annotation。

## 2. 运行时注解
这一类注解是开发者广泛使用的。基本原理是利用`反射机制`在代码运行过程中动态地执行一些操作。关于 `反射机制` 我已经在之前的文章[Java 技术之反射](/2017/04/26/Java-技术之反射/)中细致阐述过了，不熟悉的读者可以去阅读。

下面我们以两个例子来进行讲解。还是利用我们常用的 `UserBean` 对象为目标，对它内部的一些 `Annotation` 进行运行时处理。
```
public class UserBean {

    @Alias("user_name")
    public String userName;

    @Alias("user_id")
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

    @Test(value = "static_method", id = 1)
    public static void staticMethod() {
        System.out.printf("I'm a static method\n");
    }

    @Test(value = "public_method", id = 2)
    public void publicMethod() {
        System.out.println("I'm a public method\n");
    }

    @Test(value = "private_method", id = 3)
    private void privateMethod() {
        System.out.println("I'm a private method\n");
    }

    @Test(id = 4)
    public void testFailure() {
        throw new RuntimeException("Test failure");
    }
}
```

这次我在 `UserBean` 里面创建了两个自定义的 `Annotation`: `Alias` 和 `Test`，前者是用来设置变量的别名并在运行时打印，后者是调用所有被`Test`标记的方法，得出测试通过率。当然，这两个功能目前完全没有实现，只是标记了一下而已。下面我们依次来实现这两个Annotation的功能。

#### Alias 功能实现：设置变量别名并在运行时打印别名
首先，我们要创建 `Alias` 这个注解。那么要明确三个方面：

- 生命周期是什么？
- 针对的目标是什么类型？
- 内部是否有参数？

针对 `Alias` 的功能，我们可以作如下回答：
- 生命周期是`运行时`，因为要动态打印出变量的别名 -> @Retention(RetentionPolicy.RUNTIME)
- 针对的目标是 `变量` -> @Target(ElementType.FIELD)
- 内部需要维护一个 String 型的变量来保存别名 -> String value();

因此可以得到
```
@Target(ElementType.FIELD)
@Retention(RetentionPolicy.RUNTIME)
public @interface Alias {
    String value();
}
```

`Alias` 定义得到了，接下来我们要实现它的功能了，即在运行时取出变量的别名并打印。

代码如下：
```
/**
 * print alias during runtime
 */
private static void printAlias(Object userBeanObject) {
    for (Field field : userBeanObject.getClass().getDeclaredFields()) {
        if (field.isAnnotationPresent(Alias.class)) {
            Alias alias = field.getAnnotation(Alias.class);
            System.out.println(alias.value());
        }
    }
}
```

过程很简单，利用反射机制，把 `userBeanObject` 对应 Class 里所有的成员变量都找到，找出其中被 `Alias` 修饰的成员变量，然后把真实注解 `Alias` 对象取出来，把内部的 `value` 打印出来即可。 

#### `Test`功能实现：调用所有被`Test`标记的方法，得出测试通过率
同样我们要回答上面三个问题：生命周期，针对对象类型和内部参数，回答是：

- 生命周期：由于是`动态运行时`去遍历这些 `Test` 的存在，因此是 `RUNTIME`;
- 针对对象类型：因为是修饰`方法`的，因此是 `@Target(ElementType.METHOD)`;
- 内部参数：由于需要记录方法的`名称`和对应的`id`，因此需要 `String value();` `int id;`

得到如下：
```
@Target(ElementType.METHOD)
@Retention(RetentionPolicy.RUNTIME)
public @interface Test {
    String value() default ""; // 如果没有设置，那么直接取函数方法名
    int id();
}
```

接下来我们需要找到所有被 `@Test` 修饰的方法，并逐一调用。注意两点：
1. 就算是 `private` 和 `static` 修饰的方法也需要调用；
2. 在执行每个方法前后都要打印相关log，表示开始测试该方法。打印的内容要含有 `value` 和 `id`， 如果 `@Test` 里的 `value` 没有设置值，那么就取函数名为值。

可以看出，在 `UserBean` 里已经定义好了三个被 `@Test` 修饰的方法了。
```
    @Test(value = "static_method", id = 1)
    public static void staticMethod() {
        System.out.printf("I'm a static method\n");
    }

    @Test(value = "public_method", id = 2)
    public void publicMethod() {
        System.out.println("I'm a public method\n");
    }

    @Test(value = "private_method", id = 3)
    private void privateMethod() {
        System.out.println("I'm a private method\n");
    }

    @Test(id = 4)
    public void testFailure() {
        throw new RuntimeException("Test failure");
    }
```

接下来我们实现 `@Test` 的具体功能：
```
/**
 * Test methods which are be annotated with @Test
 */
private static void doTest(Object object) {
    Method[] methods = object.getClass().getDeclaredMethods();
    for (Method method : methods) {
        if (method.isAnnotationPresent(Test.class)) {
            Test test = method.getAnnotation(Test.class);
            try {
                String methodName = test.value().length() == 0 ? method.getName() : test.value(); // if test.value() is empty, use `method.getName()`
                System.out.printf("Testing. methodName: %s, id: %s\n", methodName, test.id());

                if (Modifier.isStatic(method.getModifiers())) {
                    method.invoke(null); // static method
                } else if (Modifier.isPrivate(method.getModifiers())) {
                    method.setAccessible(true);  // private method
                    method.invoke(object);
                } else {
                    method.invoke(object);  // public method
                }

                System.out.printf("PASS: Method id: %s\n", test.id());
            } catch (Exception e) {
                System.out.printf("FAIL: Method id: %s\n", test.id());
                e.printStackTrace();
            }
        }
    }
}
```

打印结果如下：

```
Testing. methodName: static_method, id: 1
I'm a static method
PASS: Method id: 1

Testing. methodName: public_method, id: 2
I'm a public method
PASS: Method id: 2

Testing. methodName: private_method, id: 3
I'm a private method
PASS: Method id: 3

Testing. methodName: testFailure, id: 4
FAIL: Method id: 4
```

全部正常打印。其中，由于 `testFailure()` 的 `@Test` 里未设置 `value()`，因此直接打印了它的函数名；针对`static`方法，直接调用`method.invoke(null)`；针对`private`，利用`method.setAccessible(true);`获取了权限。

当然这里有一点要注意，我在 `invoke method` 时，直接使用 `method.invoke(object);`，没有传任何参数。这是由于我在 `UserBean` 里写的几个方法都不用传参数。如果需要传参数的话，那就还需要再单独判断是哪个函数，并传递对应的参数进去。


## 3. 编译时注解
当 .java 文件写好了准备进行编译时，我们有另一种 Annotation 可以在这时发挥效果。

我们知道，Java 源代码编译的过程会对所有的文件进行扫描，而`编译时 Annotation` 的作用就是`在编译过程中生成代码`。在 Java 里提供了 apt 工具来处理注解，同时有一套 Mirror API 来描述编译时的程序语义结构，它可以在编译时获取到被注解 Java 元素的信息以方便我们处理。该处理过程的核心是编写注解处理器 `AnnotationProcessor` 接口。

大概说明下整体的过程。

假设我们希望用某个 `Annotation`：`@Inject` 来生成一些代码，那么我们要做下面几步：

##### 定义 @Inject
由于它是编译时注解，因此是 `RetentionPolicy.CLASS`，对象的话就是变量和构造函数，因此得到：
```
@Retention(RetentionPolicy.CLASS)
@Target({ElementType.CONSTRUCTOR, ElementType.FIELD})
public @interface Inject {
}
```

##### 定义 Processor 类
```
// Helper to define the Processor
@AutoService(Processor.class)
// Define the supported Java source code version
@SupportedSourceVersion(SourceVersion.RELEASE_7)
// Define which annotation you want to process
@SupportedAnnotationTypes("com.wingjay.annotation.Inject")
public class MyProcessor extends AbstractProcessor {  ...  }
```
##### 重写 `Processor` 内部的 `process` 方法
这个 `process` 方法会在编译时被执行到，我们可以在这个方法里进行代码生成的工作。

关于具体的代码生成部分，可以利用 `Square` 提供的 `JavaPoet` 工具：https://github.com/square/javapoet

下面有一些代码片段供参考：
```
@Override
public boolean process(Set<? extends TypeElement> annotations, RoundEnvironment roundEnv) {
	//扫描所有 Inject 标记过的元素
    Set<? extends Element> elements = roundEnv.getElementsAnnotatedWith(Inject.class);
    Set<? extends TypeElement> typeElements = ElementFilter.typesIn(elements);
    for (TypeElement element : typeElements) {

    	// 拼接待生成代码
    	ClassName currentType = ClassName.get(element);
      	MethodSpec.Builder builder = MethodSpec.methodBuilder("fromCursor")
	       .returns(currentType)
	       .addModifiers(Modifier.STATIC)
	       .addModifiers(Modifier.PUBLIC)
	       .addParameter(ClassName.get("android.database", "Cursor"), "cursor");

	    // 将这些拼接代码写入文件
        String className = ... // 设置你要生成的代码class名字
        JavaFileObject sourceFile =   processingEnv.getFiler().createSourceFile(className, element);
        Writer writer = sourceFile.openWriter();
        javaFile.writeTo(writer);
        writer.close();  
	}
	return false;
}
```


## 小结
本文在前文[Java 技术之反射](/2017/04/26/Java-技术之反射/)的基础上，对 Java 的注解 `Annotation` 做了一定的介绍。

熟练使用 `Annotation` 能在很多时候帮助代码变得更简洁，也能帮我们生成很多代码，免除重复写作相同代码，是一种很高效的编程方式。

下一篇我会为 Android 的小伙伴介绍不少你可能不太知道但非常好用的 `Android Annotation`。

谢谢。

wingjay

http://wingjay.com

![](https://avatars0.githubusercontent.com/u/9619875?v=3&s=460)
