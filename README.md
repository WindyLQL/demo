# demo
## shared_memory
```
  gcc shread.c -o read
  gcc shwrite.c -o write
```  
## libeventdemo
  * client3.c server3.c最高级写法
  * client1.c server1.c低级写法
```
  g++ client.cpp -o client -levent
  gcc client1.c -o client -levent
  g++ server.cpp -o server -levent
  gcc server.c -o server -levent
```
