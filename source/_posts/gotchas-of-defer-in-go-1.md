---
title: 5个Go的defer陷阱
date: 2019-4-10 4:16:25
tags: 
 - Golang
 - develop
abstract: 又是一篇译文
---

## 1  - nil 函数 Defer

当在返回为 nil 的函数中使用 defer，当调用 defer 时，包含 defer 的函数执行结束时会抛出 [panics](https://golang.org/ref/spec#Handling_panics)。

 

###  示例 

```go
func() {
  var run func() = nil
  defer run()

  fmt.Println("runs")
}
```

###  输出 

```go
runs

❗️ panic: runtime error: invalid memory address or nil pointer dereference
```

###  为什么？ 

>  在这个示例中，函数一直持续到结束，在函数运行 defer 之后会因為函数为零值而抛出 panic。 但是， `run()` 函数可以成功注册，因为在包含它的函数结束之前不会被调用。 
>
>  这是一个简单的例子，但同样的事情可能发生在真实环境中，所以如果你遇到类似的情况，那可能是同样的问题。 

##   2  - 循环中 defer 

 不要在循环中使用 defer，除非你确定自己在做什么。 它可能无法按设想运行。 

 但是，有时在循环中使用 defer 会很方便，例如，将函数的递归交給 defer，但是这超出了本文的讨论范围。 

![img](http://lizhongyuan.net/assets/gotchas-of-defer-in-go-1/1.png)

>  在函数中 `defer row.Close()` 直到函数結束不会执行 - 而不是在每次for循环的結束时执行。 这里的所有 defer 都会占用函数的堆空间，并可能会导致无法预料的问题。 



###  解決方案1： 

 直接调用。 

![img](http://lizhongyuan.net/assets/gotchas-of-defer-in-go-1/2.png)



###  解決方案2： 

 将工作委托给另一个函数并在那里使用defer。 这里，defer 将在每次匿名函数结束后运行。 

![img](http://lizhongyuan.net/assets/gotchas-of-defer-in-go-1/3.png)



###  其他



> 我对循环中使用 defer 进行了基准测试.  #golang Oh boy, defer is hungry. 
>
> https://t.co/WcEoojVeKq
>
> — @inancgumus



<center>👾示例代码在 [**这里**](https://play.golang.org/p/GJ7oOMdBwJ) **👾** </center>



##   3  - 包装中的 defer

 有时候你需要 defer 一个闭包为了让它更好用或因为一些其他我不能预测的原因。 例如，连接数据库，然后运行查询，最后确保断开连接。 



###  示例 

```go
type database struct{}

func (db *database) connect() (disconnect func()) {
  fmt.Println("connect")

  return func() {
    fmt.Println("disconnect")
  }
}
```

###  运行

```go
db := &database{}
defer db.connect()
 
fmt.Println("query db...") 
```

###  输出

```go
query db...
connect
```

###  为什么没有生效？ 

 这个示例没有正常连接并断开，这里是一个 bug。 这里 `connect()` 被保存了起来，直到函数结束也没有运行。 



###  解决方案

```go
func() {
  db := &database{}

  close := db.connect()
  defer close()
 
  fmt.Println("query db...")
}
```

 这里 `db.connect()`返回一個函数，当整个函数结束时，我们可以使用它来延迟断开与数据库的连接。 

###  输出

```go
connect
query db...
disconnect
```



###   **不好的做法：** 

 虽然这是不好的做法，但我想告诉你如何在没有变量的情况下做到这一点。 所以，我希望你能看到 defer 和 Go 通常是如何工作的。 

```go
func() {
  db := &database{}

  defer db.connect()()

  ..
}
```

 这段代码在技术上与上个解决方案几乎相同。 这里，第一个括号用于连接数据库（ *在* `*defer db.connect()*` *上立即执行* ） ，然后第二个括号用于在整个函数结束时延迟运行断开函数（ 返回的闭包） 。 

 发生这种情况是因为`db.connect()`创建了一个值，它是一个延迟注册闭包。 `db.connect()`的值需要被解析，并在 defer 时注册。 这与 defer 没有直接关系，但它可能可以解决你可能遇到的问题。 



##   4  - 在块中 defer

 您可能希望 defer 的函数将在块结束后运行，但它不会，它只在包含它的函数结束后执行。 对于所有块也是这样：包括 for，switch 等，除了我们之前的陷阱中看到的函数块外。 

>  因为：defer属于一个函数而不是一个块。 



####  示例

```go
func main() {

  {
    defer func() {
      fmt.Println("block: defer runs")
    }()

    fmt.Println("block: ends")
  }

  fmt.Println("main: ends")

}
```

####  输出 

```go
block: ends
main: ends
block: defer runs 
```

####  解释

 上面的 defer 只会在函数结束时才会运行，而不是在 defer 外的块结束时（ 包含延迟调用的花括号内的区域） 。 如示例代码所示，您可以使用花括号创建单独的块。 



####  另一种解决方案 

 如果你想在一个块中运行延迟，你可以将它转换为func，如匿名函数，就像 问题2 的解决方案一样。 

```go
func main() {
  func() {
    defer func() {
      fmt.Println("func: defer runs")
    }()

    fmt.Println("func: ends")
  }()

  fmt.Println("main: ends")
}
```



##   5  - defer method

 你也可以将 [methods](https://blog.learngoprogramming.com/go-functions-overview-anonymous-closures-higher-order-deferred-concurrent-6799008dde7b#61ec) 和 defer 一起使用。 这挺奇怪的， 请看。 



####  沒有指針 

```go
type Car struct {
  model string
}

func (c Car) PrintModel() {
  fmt.Println(c.model)
}

func main() {
  c := Car{model: "DeLorean DMC-12"}

  defer c.PrintModel()

  c.model = "Chevrolet Impala"
}
```

####  输出 

```go
DeLorean DMC-12
```



####  使用指針 

```go
func (c *Car) PrintModel() {
  fmt.Println(c.model)
}
```

####  输出

```go
Chevrolet Impala
```



####  这是怎么回事？ 



![img](http://lizhongyuan.net/assets/gotchas-of-defer-in-go-1/4.png)

 请谨记，传递给 defer 的参数会立即保存到一边，而不必等待 defer 运行。 

 因此，当带有传递值接收器的方法与 defer 一起使用时，接收器将在注册时被复制（ 在本例中为*Car*） ，并且对其的更改将不可见（ *Car.model* ）。 因为接收器也是输入参数，并且当它在延迟时注册时立即鉴定为“DeLorean DMC-12”。 

 另一方面，当接收器是指针时和 defer 一起使用，则会创建一个新指针，但它指向的地址与上面的“c”指针相同。 因此，对它的任何改变都将完整地反映出来。 



---