## 介绍
这个模块可以用来限制来自每一个IP的TCP连接频率和并发数。

### 配置样例

    daemon off;
    error_log logs/error.log debug;
    worker_processes 1;

    events {
        accept_mutex off;
    }

    limit_tcp 8088 8089 rate=1r/m burst=1000 nodelay;
    limit_tcp 8080 rate=1r/m burst=100 name=8080:1M concurrent=1;

    limit_tcp_deny 127.10.0.2/32;
    limit_tcp_deny 127.0.0.1;
    limit_tcp_allow 127.10.0.3;

    http {
        server {
            listen 8088;
            location / {
                echo 8088;
            }
        }

        server {
            listen 8089;
            location / {
                echo 8089;
            }
        }

        server {
            listen 8080;
            location / {
                echo 8080;
            }
        }
    }

## 指令

Syntax: **limit_tcp name:size addr:port [rate= burst= nodelay] [concurrent=]**

Default: `none`

Context: `main`

设置监听端口针对访问IP的频率和并发数限制。


Syntax: **limit_tcp_allow address | CIDR | all**

Default: `none`

Context: `main`

允许指定的网络地址访问。


Syntax: **limit_tcp_deny address | CIDR | all**

Default: `none`

Context: `main`

拒绝指定的网络地址访问。


## Copyright & License

These codes are licenced under the BSD license.

Copyright (C) 2012-2013 by Zhuo Yuan (yzprofile) <yzprofiles@gmail.com>, Alibaba Inc.

All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions
are met:

    * Redistributions of source code must retain the above copyright
    notice, this list of conditions and the following disclaimer.

    * Redistributions in binary form must reproduce the above copyright
    notice, this list of conditions and the following disclaimer in the
    documentation and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
"AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
