title: 如何在一天之内搭建以你自己名字为域名的很cool的个人博客
tags: [<一天变cool>系列, 个人博客]
---

![个人博客](/img/我的博客)

>对程序员而言，最好的简历就是个人博客和GitHub

## 零、个人博客
每个优秀的程序员都会有个人独占的一方网络空间，那里是他个人的舞台，听说过他的人会逐渐汇聚进来，认识他，熟悉他，鼓励他，赞扬他。而对他个人而言，他有了一个可以畅所欲言的小房间，他可以专研学术，聊聊情怀。同时和喜爱他的读者成为好友，共同成长。

这难道不是一件很cool的事情吗？

当你把自己个人博客搭好，就可以高冷地给朋友们发一个以你名字为域名的Link。

## 一、先看成果
教方法前先来看看最终的效果吧。[https://wingjay.com](https://wingjay.com)是本人搭建的个人博客，主要有以下几点：

    1. 个人域名: wingjay.com
    2. 无需购置服务器，本站同时挂载在Github Pages 和 GitCafe Pages上，免服务器费的同时还能做负载均衡，想想还有点小激动
    3. 在GitHub上同时管理你的博客和相应代码，再也不用担心博客遗失
    4. SSL支持，即"http://" -> "https://"，更安全也更高大上

## 二、再看兵器
 - 博客框架：[Hexo 3](https://hexo.io)，这是一款能快速、简洁且高效的博客框架，支持[Markdown编辑](https://help.github.com/articles/markdown-basics/)，自动渲染出漂亮的静态页面。
 - 前端主题：[Next](https://github.com/iissnan/hexo-theme-next)，效果参考[https://wingjay.com](https://wingjay.com)
 - 域名购买：[万网](http://wanwang.aliyun.com/)，你可以选购自己名字的域名，一年几十元左右，两杯咖啡的钱。
 - SSL：[CloudFlare](https://www.cloudflare.com)


## 三、抄起家伙
本文写作方式是`安装流程主线` + `优质参考文章`。由于网络上关于Hexo搭建博客的教程玲琅满目，若读者完全自己动手则要一篇篇找，浪费时间走弯路；相反，若作者悉数摘抄进来，反倒未必符合各人情况，且不利阅读。

所以，`主线`讲解思路，`参考`深入阅读。

下文以搭建 https://wingjay.com 个人博客为例。

### 1. GitHub Pages
在不购买服务器的前提下，我们的网站需要挂在GitHub Pages上。GitHub Pages是面向用户、组织和项目开放的公共静态页面搭建托管服务，可用于搭建个人博客。

0. 你需要拥有一个[GitHub账号](https://github.com)，去完成新手任务吧。
1. 进入[GitHub Pages](https://pages.github.com/)，一步步做，完成后就能在浏览器打开[http://wingjay.github.io](http://wingjay.github.io)了。

至此，我们已经利用GitHub Pages搭建好了个人博客雏形了。下面要做的，就是个性化了。

### 2. 安装Hexo博客框架
经过上面步骤，我们已经拥有了一个初步域名：http://username.github.io 加一个免费网络空间了。好比房间有了，但还没有任何家具。所以下面我们需要把空白的博客丰富起来。

放心，不需要你手写一大堆html、css文件，也不用找jQuery来实现酷炫的页面效果。[Hexo](https://hexo.io)是一款博客框架，它会帮我们搭建。

##### i. 安装Hexo
参考[中文文档](https://hexo.io/docs/)或[英文文档](https://hexo.io/zh-cn/docs/index.html)。完成该步后，你的电脑便拥有了Git、Node.js和Hexo。

##### ii. GitHub管理
为了让自己未来的博客和代码处在git管理之下，我们要把刚刚在Github上博客项目拉到本地。如本人创建的[https://github.com/wingjay/wingjay.github.io](https://github.com/wingjay/wingjay.github.io)，在本地创建文件夹，名字任意，此处设为`myblog`，进入该文件夹，把项目代码clone下来。
```
git clone https://github.com/wingjay/wingjay.github.io
```
好了，此时会自动在`myblog`目录下创建子文件夹`wingjay.github.io`,那里就是我们博客的代码，以后的操作都在git的管理之下了，此时默认的branch为`master`。

##### iii. 初始化Hexo
请参考[文档](https://hexo.io/docs/setup.html)。init命令中的`<folder>`就是文件夹`wingjay.github.io`。初始化后，`wingjay.github.io`里面就已经有完整的Hexo框架了。

##### iv. 熟悉Hexo
为了让读者快速了解`Hexo`，我作几个简单介绍吧。当然，更多的还是需要仔细阅读[文档](https://hexo.io/docs/writing.html)才能了解更详细。

![hexo目录结构](/img/hexo目录)

 - `_config.yml`是整体的配置文件，很多基础配置、插件配置等都需要在里面进行。要注意的是，该文件格式要求极为严格，缺少一个空格都会导致运行错误。小提示：不要用Tab缩进，用两个空格符。
 - `layout`，包括`draft、page、post`。这个就是三种文件的基本格式，其中`post`是你发表的文章，会显示在你的网站里，一篇post会包括`title标题、date日期、tags标签`等信息；`draft`是草稿，只有你在本地能看到，必须要`publish`后才能成为`post`，draft和post差别是date，因为draft没有发表，所以不需要指定日期。`page`是一个页面，对应一个新的html页面，比如[博客内容展示页](http://wingjay.com/2015/12/06/%E8%AF%B4%E4%B8%80%E8%AF%B4%E5%8D%9A%E5%AE%A2/)是一个页面，[留言本](http://wingjay.com/guestbook/)也是一个页面。
 - `public文件夹`，这个文件夹是最终会发布到网站上的真实内容。怎么理解呢？我们可以把`public`文件夹当作是真正的被用户看到的，而其他的`source、themes`等都是为`public`服务的。Hexo里有一个很重要的指令`hexo generate`，这个指令就是利用所有代码里的配置信息、source里写的文章、themes里的样式，共同生成最终的`静态html文件`，存入`public`文件夹内。在我们执行了发布指令`hexo deploy`后，就会把`public`的内容部署到`GitHub Pages`上。当用户在访问我们的博客时，他们会看到public里生成的html文件。这个概念非常重要，即`代码和真实静态页面是独立的`。
 - `generate和deploy`，`generate`会把我们的配置、文章和主题结合起来生成一堆酷炫的html静态文件放在public里面。但此时用户还看不到`本地public文件`里的页面，我们必须用后一个指令`deploy`才能把静态文件部署到`GitHub Pages`上。不过，在部署前，需要配置让它自动部署到我们前面创建的[Github项目](https://github.com/wingjay/wingjay.github.io)中。
 - `deploy`相关配置。为了能够让项目自动把public文件夹的内容部署到[GitHub项目](https://github.com/wingjay/wingjay.github.io)中，我们可以按[部署文档](https://hexo.io/docs/deployment.html)进行配置，其中选择的`branch`为`master`。此后，每次运行deploy后，项目就会自动把public文件夹内容全部覆盖到[当前的GitHub项目master分支上](https://github.com/wingjay/wingjay.github.io/tree/master)。
 - `代码`和`静态文件`分开管理。根据上面知道，每次部署后，public文件内容会`覆盖`掉项目整个master分支。这样可以实现网站`静态文件`的版本控制，但是，仔细对比这个master分支，我们会发现里面**只剩下静态文件**了，我们的代码比如source、themes统统没有了，这就导致无法对代码进行版本管理了。这意味着我换一台电脑，我就再也找不到`代码`了，只剩下一堆之前编译出来的静态文件。所以，为了对代码也进行版本控制，我们创建一个[新的分支：code](https://github.com/wingjay/wingjay.github.io/tree/code)，然后在这个分支里进行代码控制，master里则保存部署的新的静态文件。大家可以自行比对这两个branch的内容差异。

##### v. 配置Hexo
做一些基础配置即可，请参考[配置文档](https://hexo.io/docs/configuration.html)

##### vi. 小结
到这里，我们已经完成了hexo的配置，我们可以分别管理代码和静态文件。执行deploy操作后，刷新你的网页 http://username.github.io 你就能看到默认的内容了。

但此时还是默认主题，不够美观，所以下一步要配置Next主题。

### 3. 配置主题Next
Hexo主题非常多，可以参考[丰富多彩的Hexo主题](https://hexo.io/themes/)，本文选Next为主题，样式参考[我的博客](http://wingjay.com)。

进入配置阶段，最好的文档还是[官方文档](http://theme-next.iissnan.com/)，简单得不能再细致了。下面只提几点注意：

- 第三方评论系统。评论系统很重要，你可以与读者进行更多交流，配置也简单，建议采用[DISQUS](https://disqus.com/)，更国际化一点，[配置见此](http://theme-next.iissnan.com/third-party-services.html#DISUQS)。另外，前期建议开启`不登陆评论`，即在Disqus的`Comment Rule`里允许`Guest comment`。
- 创建留言板。熟悉`page`的创建与使用，[参考这里](http://www.arao.me/2015/hexo-next-theme-optimize-base/#为你的hexo网站NexT主题增加留言页)
- 给自己博客做`SEO`。有好的SEO便于搜索引擎索引你的网站，随着以后读者增多，他们可以更好搜索到你的网站。[具体方法见此](http://www.arao.me/2015/hexo-next-theme-optimize-seo/)

![Disqus评论系统](/img/Disqus评论系统)

### 4. 替换自己的域名
好了，经过上面的步骤，博客已经拥有了一个全新的主题啦。

下面，我们要对域名 http://wingjay.github.io 下手啦。

##### i. 购买域名
速速前往[万网](http://wanwang.aliyun.com/)，支付宝刷的一声，你就拥有了一个闪闪发光的个人域名啦

##### ii. 域名解析_1
以购买的域名`wingjay.com`为例，我们希望在访问这个域名时能自动进入Github Pages，所以我们要在万网建立一个CNAME纪录来帮我们做一个域名跳转：`wingjay.com` -> `wingjay.github.io`，`www.wingjay.com` -> `wingjay.github.io`。添加方法[参考这里](http://www.sudu.cn/service/detail/1/0/0/3/10036.html)，添加后可以看到两条记录：![域名解析](/img/域名解析){ImgCap}域名解析{/ImgCap}。然后万网会在世界各地的DNS服务器上添加这两条记录，当用户访问`wingjay.com`时会自动去访问`wingjay.github.io`。

##### iii. 域名解析_2
但是，此时并不能成功访问，因为github pages是有限制的，它不允许任意域名都跳转过来，而是只限制一个域名，而且这个域名必须声明在CNAME文件中。

所以，我们需要添加一个CNAME文件到项目的master中才行，[参考这里](https://help.github.com/articles/adding-a-cname-file-to-your-repository/)。读者可以参考本人的[CNAME文件内容](https://github.com/wingjay/wingjay.github.io/blob/master/CNAME)。

不过，对于`Hexo 3`，**这里有一个坑要注意**：大家应该还记得上文说的，master分支里的内容都是自动生成的，而且会完全覆盖之前的内容。如果我们直接创建一个新文件CNAME，填好域名。但会发现在下一次部署后这个文件就消失了。不用惊讶，因为hexo并不会自动生成CNAME文件，所以在部署时被覆盖删除了。

所以，我们就需要这个CNAME工具[hexo-generator-cname](https://github.com/leecrossley/hexo-generator-cname)，这时会自动在public里生成一个CNAME文件，把你的域名加进去再部署一下吧！

### 5. HTTP -> HTTPS
HTTPS是安全版的HTTP协议，它在http协议与TCP之间加入SSL层，采用端口443，不仅会对传输数据加密，还会进行身份验证。当然个人博客并没有强制性要求采用该协议，这也只是本人的好奇而为。

目前Github Pages已经支持https了，但是不支持自定义证书。不过我们可以利用[CloudFlare](https://www.cloudflare.com)来实现。具体实现可以[参考这里](https://www.benburwell.com/posts/configuring-cloudflare-universal-ssl/)

### 四、总结
经过上面的步骤，我们已经能够通过访问自己的域名进入自己酷炫的博客了。本文的任务也就告一段落。

除了上面的功能，本人还完成了`支持双域名同时登陆`，其中，支持双域名的解决思路是考虑到[Github Pages的CNAME纪录只允许添加一个域名](https://help.github.com/articles/adding-a-cname-file-to-your-repository/)，所以本人又在[Gitcafe](https://gitcafe.com)上部署了一套。不过考虑到这点大家不一定能用的上，就没有做介绍，有需要的话可以看下文的联系方式联系我。

### 关于作者
欢迎各位关注[我的Github](https://github.com/wingjay) https://github.com/wingjay 和 [我的个人博客](http://wingjay.com)，如果有问题，可以给我留言或发邮件<mailto:yinjiesh@126.com>












