#!/bin/bash 

source ./env

#日志输出
log_output()
{
    #定义日志类别：1表示正常日志 2表示异常日志
    log_class=$1
    log_str=$2
    date_str=$(date +%Y-%m-%d" "%H:%M:%S)
    log_dir=./log
    [ ! -d "$log_dir" ] && mkdir -p "$log_dir" 
    if [ $log_class -eq 1 ]
    then
        echo "$date_str [info] $log_str" >> "${log_dir}/clean.log"
    elif [ $log_class -eq 2 ]
    then
        echo "$date_str [error] $log_str" >> "${log_dir}/clean.log"
    fi
}

get_task_state()
{
    task_state=$(curl -s -u "${nexus_user}":"${nexus_pwd}" -X 'GET' "${nexus_url}/service/rest/v1/tasks/${compcat_task_id}" \
    -H 'accept: application/json' | jq .currentState)
}


#执行blob compcat定时任务，此任务是真正的将组件从磁盘清除
exec_blob_compcat_task()
{
    get_task_state
    if [ "$task_state" == "" ]
    then
        log_output 2 "Blob Compcat任务不存在"
    elif [ "$task_state" == \"RUNNING\" ]
    then
        log_output 1 "Blob Compcat清理任务正在运行, 请等待执行完成后重新手动执行。"
    else
        http_code=$(curl -s -u "${nexus_user}":"${nexus_pwd}" -o /dev/null  -w "%{http_code}\n" -X 'POST' "${nexus_url}/service/rest/v1/tasks/${compcat_task_id}/run" \
        -H 'accept: application/json')
        echo "$http_code" 
        if [ "$http_code" -eq 204 ]; then
            log_output 1 "Blob Compcat任务正已启动"
        elif [ "$http_code" -eq 405 ]; then
            log_output 2 "Blob Compcat任务处于禁止状态, 启动失败"
        else
            log_output 2 "Blob Compcat任务正启动失败"
        fi
    fi
}

exec_blob_compcat_task