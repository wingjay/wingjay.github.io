title: Java的equals与hashcode对比分析
date: 2017-03-29 21:23:53
categories:
  - 深入理解Java技术
tags: Java
---
>在阅读《Effective Java》第3章里读到了关于 equals() 和 hashcode() 的一些介绍，这两个方法是很多Java程序员容易弄混的，因此本文针对这两个方法的用法和具体实现来做一些介绍。

<!-- more -->

## equals() 与 hashcode() 的用处？
我们一般用`equals()`来比较两个对象的`逻辑意义`上的值是否相同。举个例子：
```java
class Person {
    String name;
    int age;
    long id;
}
```
我们现在有两个Person的对象，person1 和person2，那么什么时候这两个是相等的呢？对于两个人而言，我们认为如果他们俩名字、年龄和ID都完全一样，那么就是同一个人。也就是说，如果
```
person1.name = person2.name
person1.age = person2.age
person1.id = person2.id
```
那么我们就认为 `person1.equals(person2)=true`。这就是表示equals是指二者逻辑意义上相等即可。

而 hashcode() 则是对一个对象进行hash计算得到的一个散列值，它有以下特点：
1. 对象x和y的hashcode相同，不代表两个对象就相同(x.equals(y)=true)，可能存在hash碰撞；不过hashcode如果不相同，那么一定是两个不同的对象
2. 如果两个对象的equals()相等，那么hashcode一定相等。
所以我们一般可以用hashcode来快速比较两个对象`互异`，因为如果`x.hashcode() != y.hashcode()`，那么`x.equals(y)=false`。

## equals() 的特性
很多时候我们想要重写某个自定义object的equals()方法，那么一定要记住，你的equals()方法必须满足下面四个条件：
1. 自反性：对于非null的对象x，必须有 `x.equals(x)=true`；
2. 对称性：如果 `x.equals(y)=true`，那么`y.equals(x)`必须也为`true`；
3. 传递性：如果`x.equals(y)=true`而且`y.equals(z)=true`，那么`x.equals(z)`必须为`true`；
4. 对于非null的对象x，一定有`x.equals(null)=false`

## 如何重载 equals() 方法呢？
一般而言，如果你要重载 equals() 方法，有下面一套模版代码可以参考：
1. 首先使用 `==` 来判断`两个对象是否引用相同`；
2. 使用 `instanceof` 来判断`两个对象是否类型相同`；
3. 如果类型相同，则把待比较参数转型；
4. 比较两个对象内部每个逻辑值是否相等，只有全部相等才返回true，或者返回false；
5. 测试这个方法是否能满足上面几个特性。

## Java 源码 String 里 equals() 和 hashcode() 实现
看完上面的特性和重载方法你可能有点头大，下面我们来看一下Java里的 String 是如何实现的吧，是否满足上面几个特性呢。
```
public boolean equals(Object anObject) {
    if (this == anObject) {
        return true;
    }
    if (anObject instanceof String) {
        String anotherString = (String)anObject;
        int n = value.length;
        if (n == anotherString.value.length) {
            char v1[] = value;
            char v2[] = anotherString.value;
            int i = 0;
            while (n-- != 0) {
                if (v1[i] != v2[i])
                    return false;
                i++;
            }
            return true;
        }
    }
    return false;
}
```
可以看到，上面的方法依次执行了下面的步骤：
1. 比较引用`this == anObject`；
2. 判断类型 `anObject instanceof String`；
3. 转型 `String anotherString = (String)anObject`；
4. 比较逻辑值 对 String 而言，首先要 `length` 相等 `n == anotherString.value.length`；然后要每一个字符相等，见代码，最后返回结果。

下面我写了一段测试代码来验证是否符合上面几点特性：
```
private static void testStringEquals() {
    String x = "First";
    String y = "First";
    String z = new String("First");
    System.out.println(x.equals(x));
    System.out.println((x.equals(y) && y.equals(x)));
    if (x.equals(y) && y.equals(x)) {
        System.out.println(x.equals(z));
    }
    System.out.println(x.equals(null));
}
```
打印结果如下：
```
true
true
true
false
```
说明是符合的。

然后我们再看下 hashcode() 的源代码实现，我们知道，hashcode的含义是计算hash散列值，其实就是对一个对象快速计算一个散列值，用来`判异`使用：只要 hashcode() 不同，那么两个对象一定不同。下面我们看下 String 是如何计算自己的hash值的。
```java
private final char value[]; /** The value is used for character storage. */
private int hash; /** Cache the hash code for the string Default to 0 */

public int hashCode() {
    int h = hash; 
    if (h == 0 && value.length > 0) { 
        char val[] = value;
        for (int i = 0; i < value.length; i++) {
            h = 31 * h + val[i];
        }
        hash = h;
    }
    return h;
}
```
其中用来计算 hashcode 主要是这段代码
```
for (int i = 0; i < value.length; i++) {
    h = 31 * h + val[i];
}
```
其中，value是内部存储string值的字符数组。计算hashcode的方法就是依次遍历每一个字符，乘以31后再加上下一个字符。例如"a"的hashcode就是 97；"aa"的hashcode是 `31*97+97`=3104。因此可以看出，`hashcode不同的两个 String 对象一定不是同一个对象`。

## 谨记：重载 equals() 时要保证：两个equal的对象一定有相同的hashcode
很多人在重载 equals() 时忽视了这一点，没有保证两个equal的对象具备相同的hashcode，从而导致了奇怪的错误。

下面举一个例子，我先只重载 `PhoneNumberWithoutHashcode` 的 equals() 方法：
```
class PhoneNumberWithoutHashcode {
    final short countryCode;
    final short number;
    public PhoneNumberWithoutHashcode(int countryCode, int number) {
        this.countryCode = (short) countryCode;
        this.number = (short) number;
    }

    @Override
    public boolean equals(Object obj) {
        // 1. check == reference
        if(obj == this) {
            return true;
        }
        // 2. check obj instance
        if (!(obj instanceof PhoneNumberWithoutHashcode))
            return false;

        // 3. compare logic value
        PhoneNumberWithoutHashcode anObj = (PhoneNumberWithoutHashcode) obj;
        return anObj.countryCode == this.countryCode 
                && anObj.number == this.number;
    }        
}
```
下面我们来创建两个相同的对象，看看它们的 equals() hashcode() 返回值如何。
```
private static void test() {
    PhoneNumberWithoutHashcode p1 = new PhoneNumberWithoutHashcode(86, 123123);
    PhoneNumberWithoutHashcode p2 = new PhoneNumberWithoutHashcode(86, 123123);
    System.out.println("p1.equals(p2)=" + p1.equals(p2));
    System.out.println("p1.hashcode()=" + p1.hashCode());
    System.out.println("p2.hashcode()=" + p2.hashCode());    
}
```
可以得到结果如下:
```
p1.equals(p2)=true
p1.hashcode()=1846274136
p2.hashcode()=1639705018
```
可以看出，二者是 equals 的，但是hashcode不一样。这违背了 Java准则，会导致什么结果呢？

```java
private static void test() {
    PhoneNumberWithoutHashcode p1 = new PhoneNumberWithoutHashcode(86, 123123);
    PhoneNumberWithoutHashcode p2 = new PhoneNumberWithoutHashcode(86, 123123);
    System.out.println("p1.equals(p2)=" + p1.equals(p2));
    
    HashMap<PhoneNumberWithoutHashcode, String> map = new HashMap<>();
    map.put(p1, "TheValue");
    System.out.println("Result: " + map.get(p2));
}
```

读者觉得会打印什么呢？`Result: TheValue` 吗？我们来看下运行结果：
```
p1.equals(p2)=true
Result:  null
```
问题来了，p1和p2是equal的，但是确不是同样的key，至少对于HashMap而言，它们俩不是同一个key，为什么呢？

我们看一下 HashMap 是怎么put和get的吧。
```
public V put(K key, V value) {
    return putVal(hash(key), key, value, false, true);
}
public V get(Object key) {
    Node<K,V> e;
    return (e = getNode(hash(key), key)) == null ? null : e.value;
}
```
从这段代码可以看到，p1 和 p2 被存储时就计算了一次 `hash(key)`，如下:
```
static final int hash(Object key) {
    int h;
    return (key == null) ? 0 : (h = key.hashCode()) ^ (h >>> 16);
}
```
其实就是调用了 `key.hashCode()` 方法，而我们知道虽然 `p1.equals(p2)=true`，但是`p1.hashCode() != p2.hashCode()`，因此 p1 和 p2 对 HashMap 而言压根就是两个 key，当然互相取不到对方的 value了。

那么要如何改进这个类呢？我们再来实现它的 hashcode 方法吧。
```
class PhoneNumber {
    protected final short countryCode;
    protected final short number;

    public PhoneNumber(int countryCode, int number) {
        this.countryCode = (short) countryCode;
        this.number = (short) number;
    }

    @Override
    public boolean equals(Object obj) {
        // 1. check == reference
        if (this == obj)
            return true;

        // 2. check obj instance
        if (!(obj instanceof PhoneNumber))
            return false;

        // 3. compare logic value
        PhoneNumber target = (PhoneNumber) obj;
        return target.number == this.number
                && target.countryCode == this.countryCode;
    }

    @Override
    public int hashCode() {
        return (31 * this.countryCode) + this.number;
    }
}
```
这时我们的测试代码：
```
private static void test() {
    PhoneNumber p1 = new PhoneNumber(86, 12);
    PhoneNumber p2 = new PhoneNumber(86, 12);
    System.out.println("p1.equals(p2)=" + p1.equals(p2));
    System.out.println("p1.hashcode()=" + p1.hashCode());
    System.out.println("p2.hashcode()=" + p2.hashCode());

    HashMap<PhoneNumber, String> map = new HashMap<>(2);
    map.put(p1, "TheValue");
    System.out.println("Result: " + map.get(p2));
}
```
打印结果如下：
```
p1.equals(p2)=true
p1.hashcode()=88076
p2.hashcode()=88076
Result: TheValue
```
说明重载hashcode后就能保证 `PhoneNumber` 在 `HashMap` 里正常运行了，毕竟像这种 HashMap HashSet 之类的都要基于对象的hash值。

## 小结
如果存在遗漏错误欢迎读者提出。

谢谢。

wingjay

http://wingjay.com

如果有问题，可以给我留言或发邮件<mailto:yinjiesh@126.com>