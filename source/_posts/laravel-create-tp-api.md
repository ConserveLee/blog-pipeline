---
title: laravel一个路由规则复现tp5 RESTful API
date: 2018-12-06 18:02:25
tags: 
 - laraval
 - develop
abstract: 如何让laravel不那么优雅
---
一个突发奇想



其实很简答：

```php
Route::any(
    '{url}',
    function ($url) 
    {
      $result = explode('/',$url);
      $controller = ucwords($result[0]);
      $action = isset($result[1]) ? $result[1] : 'index';
      if ( isset($result[2]) ) return ["code"=>"0","msg"=>"action worng"];
      $class = App::make('App\\Http\\Controllers\\Api\\' . $controller . 'Controller');
    		return $class->$action();
    }
)->where('url', '.+');

```

如果想改全局可以去web.php改，不过这样感觉太过分了 = =