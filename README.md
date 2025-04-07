# 功能说明
1 此脚本用来按照份数来清理应用包，目前只能清理release包，snaphost包无法清理。 
2、重要说明
  data目录：在此目录下面自定义创建一个文件，文件中定义一个需要清理的包的属性。如：
  com.cenboomh.base|report-center-server|8yy  表示需要清理路径为com.cenboomh.base下面，名称为report-center-server，版本带有8yy后缀的包（report-center-server-1.1.0-8yy.war）。 
  com.cenboomh.base||  表示清理com.cenboomh.base下面所有的包
  com.cenboomh.base||8yy  表示清理com.cenboomh.base下面所有的包，但是包名称带有8yy后缀的包（report-center-server-1.1.0-8yy.war）。

# 脚本功能使用说明

- ## 功能1：获取或清理指定groupID下面的包
```shell
    sh nexus_clean.sh [-d] -g 'com.th.supcom.portal|xxx|xxxx'
```   
- ## 功能2：获取或清理指定项目下面所有包
```shell
    sh nexus_clean [-d] -p "TJH,TJXN"
```
- ## 功能3：获取或清理所有项目
```shell     
    sh nexus_clean [-d] --all
```
- ## 功能4：指定清理某个生成目录下面的包
```shell
    sh nexus_clean -d --time 20240702151357
```


# 相关条件和限制说明
 1. -d 是可选项， 加入-d,表示要进行清理操作，不加-d表示只做查询
 2. -g 表示group , -p 表示project  ，此两个参数不能一起用
 3. --all 表示，直接扫描data目录下面的所有项目
 4. 如果只清理已存生成的清理信息，使用-d 然后使用 --time参数，指定时间点所表示的目录
 5. -d 选项和--time选项不能单独使用


# 环境变量说明
env文件中记录着脚本可以设置的环境变量，根据实际需求进行修改：

| 参数名称 | 参数说明 | 示例 |
| ---- | ---- | ---- |
| nexus_url | nexus仓库地址 | http://192.168.30.70:8081 |
| nexus_user | nexus账号 | |
| nexus_pwd | nexus密码 | |
| retention | 保留份数 | |
| s_repositor | 清理仓库名称 | Releases |
| compcat_task_id | nexus blob 定时任务id | "426ad0d6-72b3-411c-b06b-285a7cc6436c" |

# 定时任务的配置
由于本脚本使用的是nexus rest api方式进行清理，所有定时任务可以配置在任何的安装有curl工具的linux服务器上。为分散压力，建议每天清理不同的项目。crontab配置样例如下：
```shell
# Monday to Sunday
0 1 * * 1 cd /opt/earth/Nexus3Clean; sh nexus_clean.sh -d -p "DLRM,FXZYY,GSSFY,GZSRM"
0 1 * * 2 cd /opt/earth/Nexus3Clean; sh nexus_clean.sh -d -p "HBHA,HNSZL,HTC,LYG"
0 1 * * 3 cd /opt/earth/Nexus3Clean; sh nexus_clean.sh -d -p "LYGSY,LYGYKYY,LZSFY,MLDYYY"
0 1 * * 4 cd /opt/earth/Nexus3Clean; sh nexus_clean.sh -d -p "NTRM,QJZYY,SPBRM"
0 1 * * 5 cd /opt/earth/Nexus3Clean; sh nexus_clean.sh -d -p "SYTH,ZJYYXM,TJXN,TKX"
0 1 * * 6 cd /opt/earth/Nexus3Clean; sh nexus_clean.sh -d -p "WHBYY,XZRM,YJSYY,YXRM"
0 1 * * 0 cd /opt/earth/Nexus3Clean; sh nexus_clean.sh -d -p "ZGYGT,TJH,NYEYYGT"
```