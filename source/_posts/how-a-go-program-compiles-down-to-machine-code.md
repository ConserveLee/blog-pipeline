---
title: Go程序如何编译为机器代码
date: 2019-4-22 10:51:26
tags: 
 - go
 - develop
abstract: 翻译文章
---
# Go程序如何编译为机器代码

> 省略原文一些广告

今天，我们将看看Go 1.11的编译器，以及它如何将Go源代码编译成可执行文件，以便了解我们使用的工具是如何工作的。 我们还将看到为什么Go代码如此之快，以及编译器对此的作用。 我们将看一下编译器的三个阶段：

- 扫描程序，将源码转换为token(标记)，供解析器使用。
- 解析器，将token转换为抽象语法树，供代码生成使用。
- 生成代码，将抽象语法树转换为机器代码。

*注意：我们将要使用的包（* **go / scanner** *，* **go / parser** *，* **go / token** *，* **go / ast** *等）不是Go编译器真正使用的。*  *但是，真实的Go编译器具有非常相似的结构和语义。* 

### Scanner/扫描器 

 每个编译器的第一步是将原始源码文本分解为token，这是由扫描程序（也称为词法分析器）完成的。 标记可以是关键字，字符串，变量名，函数名等。每个有效的程序“单词”由token表示。 对于Go来说，这可能意味着我们“token”了“package”，“main”，“func”等等。 

 每个token由其在源码中的位置，类型和原始文本表示。  Go甚至允许我们使用**go / scanner**和**go / token**包在Go程序中自己执行扫描程序。 这意味着我们可以在扫描完成后检查Go程序的程序。 为此，我们将创建一个打印Hello World程序的所有标记的简单程序。 

 该程序将如下所示： 

```go
package main

import (
  "fmt"
  "go/scanner"
  "go/token"
)

func main() {
  src := []byte(`package main
import "fmt"
func main() {
  fmt.Println("Hello, world!")
}
`)

  var s scanner.Scanner
  fset := token.NewFileSet()
  file := fset.AddFile("", fset.Base(), len(src))
  s.Init(file, src, nil, 0)

  for {
     pos, tok, lit := s.Scan()
     fmt.Printf("%-6s%-8s%q\n", fset.Position(pos), tok, lit)

     if tok == token.EOF {
        break
     }
  }
}
```

我们将创建源码字符串，并初始化**scan.Scanner**结构，扫描我们的源代码。 我们尽可能多地调用**Scan（）**并打印token的位置，类型和文字，直到我们到达文件结束（ **EOF** ）标记。 

 当我们运行程序时，它将打印以下内容： 

```go
1:1   package "package"
1:9   IDENT   "main"
1:13  ;       "\n"
2:1   import  "import"
2:8   STRING  "\"fmt\""
2:13  ;       "\n"
3:1   func    "func"
3:6   IDENT   "main"
3:10  (       ""
3:11  )       ""
3:13  {       ""
4:3   IDENT   "fmt"
4:6   .       ""
4:7   IDENT   "Println"
4:14  (       ""
4:15  STRING  "\"Hello, world!\""
4:30  )       ""
4:31  ;       "\n"
5:1   }       ""
5:2   ;       "\n"
5:3 EOF ""
```

 在这里，我们可以看到Go解析器在编译程序时所使用的内容。 我们还可以看到扫描器添加了分号，用于将其放置在其他编程语言（如C）中。这解释了为什么Go不需要分号：它们由扫描器智能放置。 

### Parser/分析器 

 扫描源码后，它将被传递至解析器。 解析器是编译器的一个阶段，它将标记转换为抽象语法树（AST）。  AST是源码的结构化表示。 在AST中，我们将能够看到程序结构，例如函数和常量声明。 

  Go再次为我们提供了解析程序的包并查看AST： **go / parser**和**go / ast** 。 我们可以像这样使用它们来打印完整的AST： 

```go
package main

import (
  "go/ast"
  "go/parser"
  "go/token"
  "log"
)

func main() {
  src := []byte(`package main
import "fmt"
func main() {
  fmt.Println("Hello, world!")
}
`)

  fset := token.NewFileSet()

  file, err := parser.ParseFile(fset, "", src, 0)
  if err != nil {
     log.Fatal(err)
  }

  ast.Print(fset, file)
}
```

输出：

```
     0  *ast.File {
     1  .  Package: 1:1
     2  .  Name: *ast.Ident {
     3  .  .  NamePos: 1:9
     4  .  .  Name: "main"
     5  .  }
     6  .  Decls: []ast.Decl (len = 2) {
     7  .  .  0: *ast.GenDecl {
     8  .  .  .  TokPos: 3:1
     9  .  .  .  Tok: import
    10  .  .  .  Lparen: -
    11  .  .  .  Specs: []ast.Spec (len = 1) {
    12  .  .  .  .  0: *ast.ImportSpec {
    13  .  .  .  .  .  Path: *ast.BasicLit {
    14  .  .  .  .  .  .  ValuePos: 3:8
    15  .  .  .  .  .  .  Kind: STRING
    16  .  .  .  .  .  .  Value: "\"fmt\""
    17  .  .  .  .  .  }
    18  .  .  .  .  .  EndPos: -
    19  .  .  .  .  }
    20  .  .  .  }
    21  .  .  .  Rparen: -
    22  .  .  }
    23  .  .  1: *ast.FuncDecl {
    24  .  .  .  Name: *ast.Ident {
    25  .  .  .  .  NamePos: 5:6
    26  .  .  .  .  Name: "main"
    27  .  .  .  .  Obj: *ast.Object {
    28  .  .  .  .  .  Kind: func
    29  .  .  .  .  .  Name: "main"
    30  .  .  .  .  .  Decl: *(obj @ 23)
    31  .  .  .  .  }
    32  .  .  .  }
    33  .  .  .  Type: *ast.FuncType {
    34  .  .  .  .  Func: 5:1
    35  .  .  .  .  Params: *ast.FieldList {
    36  .  .  .  .  .  Opening: 5:10
    37  .  .  .  .  .  Closing: 5:11
    38  .  .  .  .  }
    39  .  .  .  }
    40  .  .  .  Body: *ast.BlockStmt {
    41  .  .  .  .  Lbrace: 5:13
    42  .  .  .  .  List: []ast.Stmt (len = 1) {
    43  .  .  .  .  .  0: *ast.ExprStmt {
    44  .  .  .  .  .  .  X: *ast.CallExpr {
    45  .  .  .  .  .  .  .  Fun: *ast.SelectorExpr {
    46  .  .  .  .  .  .  .  .  X: *ast.Ident {
    47  .  .  .  .  .  .  .  .  .  NamePos: 6:2
    48  .  .  .  .  .  .  .  .  .  Name: "fmt"
    49  .  .  .  .  .  .  .  .  }
    50  .  .  .  .  .  .  .  .  Sel: *ast.Ident {
    51  .  .  .  .  .  .  .  .  .  NamePos: 6:6
    52  .  .  .  .  .  .  .  .  .  Name: "Println"
    53  .  .  .  .  .  .  .  .  }
    54  .  .  .  .  .  .  .  }
    55  .  .  .  .  .  .  .  Lparen: 6:13
    56  .  .  .  .  .  .  .  Args: []ast.Expr (len = 1) {
    57  .  .  .  .  .  .  .  .  0: *ast.BasicLit {
    58  .  .  .  .  .  .  .  .  .  ValuePos: 6:14
    59  .  .  .  .  .  .  .  .  .  Kind: STRING
    60  .  .  .  .  .  .  .  .  .  Value: "\"Hello, world!\""
    61  .  .  .  .  .  .  .  .  }
    62  .  .  .  .  .  .  .  }
    63  .  .  .  .  .  .  .  Ellipsis: -
    64  .  .  .  .  .  .  .  Rparen: 6:29
    65  .  .  .  .  .  .  }
    66  .  .  .  .  .  }
    67  .  .  .  .  }
    68  .  .  .  .  Rbrace: 7:1
    69  .  .  .  }
    70  .  .  }
    71  .  }
    ..  .  .. // Left out for brevity
    83 }
```

在输出中，可以看到有关该程序的一些信息。 在**Decls**字段中，有一个文件中所有声明的列表，例如导入，常量，变量和函数。 在本例子中，只有两个声明：**fmt**包和main函数。 

 为了进一步消化它，我们可以看一下这个图，它是上述数据的表示，但只包括类型，红色代表与节点对应的代码： 

![1](http://lizhongyuan.net/assets/how-a-go-program-compiles-down-to-machine-code/0.png)

主要功能由三部分组成：名称，声明和正文。 名称表示main的值的标识符。 声明由Type字段指定，并包含参数列表和返回类型（如果我们指定了参数列表和返回类型）。 正文包含程序所有行的语句列表，在本例子中，只有一行。 

 单个**fmt.Println**语句由AST中的一部分组成。 该语句是一个**ExprStmt** ，表示一个表达式，例如，它可以是一个函数调用，就像本例子一样，或者它可以是一个文字，一个二进制操作（例如加法和减法），一个一元操作（用于实例否定一个数字）等等。任何能在函数中调用并使用的东西都可以是表达式。 

 我们的**ExprStmt**包含一个**CallExpr** ，它是我们实际的函数调用。 包括几个部分，其中最重要的部分是**Fun**和**Args** 。  Fun包含对函数调用的引用，在这种情况下，它是一个**SelectorExpr** ，因为我们从fmt包中选择**Println**标识符。 但是，在AST中，编译器还不知道**fmt**是一个包，它也可能是AST中的一个变量。 

  Args包含表达式列表，这些表达式是函数的参数。 在这种情况下，我们将一个文字字符串传递给函数，因此它由一个类型为**STRING**的**BasicLit**表示。 

 很明显，我们能够从AST中推断出很多。 这意味着我们还可以进一步检查AST并查找文件中的所有函数调用。 为此，我们将使用**ast**包中的**Inspect**函数。 此函数将递归遍历树，并允许我们检查来自所有节点的信息。 

 要提取所有函数调用，我们将使用以下代码： 

```go
package main

import (
  "fmt"
  "go/ast"
  "go/parser"
  "go/printer"
  "go/token"
  "log"
  "os"
)

func main() {
  src := []byte(`package main
import "fmt"
func main() {
  fmt.Println("Hello, world!")
}
`)

  fset := token.NewFileSet()

  file, err := parser.ParseFile(fset, "", src, 0)
  if err != nil {
     log.Fatal(err)
  }

  ast.Inspect(file, func(n ast.Node) bool {
     call, ok := n.(*ast.CallExpr)
     if !ok {
        return true
     }

     printer.Fprint(os.Stdout, fset, call.Fun)
     fmt.Println()

     return false
  })
}
```

我们在这里做的是查找所有节点以及它们是否为*** ast.CallExpr**类型，我们刚才看到它代表了我们的函数调用。 如果是，我们将使用fmt包打印**Fun**成员中存在的函数的名称。 

 此代码的输出将是： 

  **fmt.Println** 

 这确实是我们简单程序中唯一的函数调用，所以我们找到了所有函数调用。 

 构建AST后，将使用GOPATH或Go 1.11及更高版本的模块将所有导入解析。 然后，将检查类型，并应用一些初步优化，使程序执行得更快。 

### Code generation/生成代码

//TODO