#!/bin/bash
#脚本功能： 清理nexus release仓库制品
#编写人：wwu

source ./env

#日志输出
log_output()
{
    #定义日志类别：1表示正常日志 2表示异常日志
    log_class=$1
    log_str=$2
    date_str=$(date +%Y-%m-%d" "%H:%M:%S)
    log_dir="${clean_path}"/log
    [ ! -d "$log_dir" ] && mkdir -p "$log_dir" 
    if [ "$log_class" -eq 1 ]
    then
        echo "$date_str [info] $log_str" >> "${log_dir}/clean.log"
    elif [ "$log_class" -eq 2 ]
    then
        echo "$date_str [error] $log_str" >> "${log_dir}/clean.log"
    elif [ "$log_class" -eq 3 ]
    then 
        echo "$date_str [warning] $log_str" >> "${log_dir}/clean.log"
    fi
}

#数据生成目录
generate_data_dir()
{
    if [ -z "$project_name" ]
    then
        data_dir=$(pwd)/jsondata/${timestring}/${groupid}
        log_output 1 "创建group子目录:${groupid}" 
    else
        data_dir=$(pwd)/jsondata/${timestring}/${project_name}/${groupid}
        log_output 1 "创建项目group子目录:${project_name}/${groupid}" 
    fi
    mkdir -p "$data_dir"
}

#artifacid和areacode是否有值使用不同的正则表达式
choice_regular_str()
{
    if [ "$areacode" = "" ]; then
        regular_str="\s+[0-9]+\.[0-9]+\.[0-9]+$"
    else
        regular_str="\s+[0-9]+\.[0-9]+\.[0-9]+-${areacode}$"
    fi
}

#通过groupId和repository搜索组件
search_components_bygroupID() 
{
    curl -s -u "${nexus_user}":"${nexus_pwd}" \
    -X GET "${nexus_url}/service/rest/v1/search?repository=${s_repository}&group=${groupid}" \
    -H "accept: application/json" > "${data_dir}"/temp
    sleep 0.5
}

search_components_by_artifacid_groupID() 
{

    curl -s -u "${nexus_user}":"${nexus_pwd}" \
    -X GET "${nexus_url}/service/rest/v1/search?repository=${s_repository}&group=${groupid}&name=${artifacid}" \
    -H "accept: application/json" > "${data_dir}"/temp
    sleep 0.5
}

#Nexus每次调用一次API只会查出一部分数据，通过加入continuationToken值继续查询下一页
search_components_bycontinuationToken()
{
    curl -s -u "${nexus_user}":"${nexus_pwd}"  -X 'GET' \
    "${nexus_url}/service/rest/v1/search?continuationToken=${iscontinuationToken}&repository=${s_repository}&group=${groupid}" \
     -H "accept: application/json" > "${data_dir}"/temp
     sleep 0.5
}

search_components_bycontinuationToken_artifacid()
{
    curl -s -u "${nexus_user}":"${nexus_pwd}"  -X 'GET' \
    "${nexus_url}/service/rest/v1/search?continuationToken=${iscontinuationToken}&repository=${s_repository}&group=${groupid}&name=${artifacid}" \
     -H "accept: application/json" > "${data_dir}"/temp
     sleep 0.5
}

#获取所有组件信息
get_all_components_list() 
{
    if [ "${artifacid}" == "" ]; then
        search_components_bygroupID
    else
        search_components_by_artifacid_groupID
    fi
    cd "${data_dir}" || exit
    iscontinuationToken=$(jq -r .continuationToken < temp)
    #log_output 1 "获取continuationToken:$iscontinuationToken"
    #iscontinuationToken值为null，表示查询完成
    until [ "${iscontinuationToken}" == null ]
    do
        jq -r '.items[] | "\(.id) \(.group) \(.name) \(.version)"'  ./temp | grep -iE "${regular_str}" >> list
        if [ "${artifacid}" == "" ]; then
            search_components_bycontinuationToken
        else
            search_components_bycontinuationToken_artifacid
        fi
        iscontinuationToken=$(jq -r .continuationToken < temp)
        #log_output 1 "获取continuationToken:$iscontinuationToken"
    done
    jq -r '.items[] | "\(.id) \(.group) \(.name) \(.version)"'  temp | grep -iE "${regular_str}" >> list
}

generate_clean_info()
{
    local list_path
    list_path=$1
    cd "${list_path}" || { 
        echo "Cannot change to direcotry." 
        exit 1 
        }
    if [ -s list ]; then 
        #排序，包名称正序，版本倒叙，-V可以用于*.*.*类版本排序
        sort -k 3,3 -k 4,4rV list -o list.sortd && rm -f list
        #保留retention个版本，找出超过retention个版本以外的版本，写入list.delete文件
        awk -v 'OFS=|' '{war[$3]++}END{ for(i in war){ print i, war[i]} }' list.sortd | while read -r line || [[ -n ${line} ]]
        do
            version_num=$(echo "$line" | cut -d '|' -f 2)
            version_name=$(echo "$line" | cut -d '|' -f 1)
            if [[ ${version_num} -gt ${retention} ]]  #${retention}
            then
                delete_num=$(( version_num - retention ))
                #version_name后面必须有个空格
                #grep "${version_name} " list.sortd | tail -$delete_num >> list.delete --这种方式会出现问题
                grep -E "\s${version_name}\s" list.sortd | tail -$delete_num >> list.delete
            fi
        done

        if [ -f "list.delete" ]; then 
            log_output 1 "${list_path##*/} 已生成清理文件,请查看${list_path}/list.delete"
        else
            log_output 1 "${list_path##*/} 数量少于${retention},未生成清理文件"
        fi
    else
        log_output 3 "${list_path##*/}没有查询到数据,请检查参数是否正确"
    fi

}

#获取单个groupID下的清理信息
get_single_groupID_clean_info()
{
    generate_data_dir
    choice_regular_str
    get_all_components_list
    generate_clean_info "$data_dir"
}

#获取单个项目的清理信息
get_single_project_clean_info()
{
    project_file=$(pwd)/data/${project_name}
    if [ -f "$project_file" ]
    then
        log_output 1 "开始进行${project_name}项目清理任务"
        while read -r line || [[ -n ${line} ]]
        do
            groupid=$(echo "$line" | cut -d '|' -f 1)
            artifacid=$(echo "$line" | cut -d '|' -f 2)
            areacode=$(echo "$line" | cut -d '|' -f 3)
            generate_data_dir
            choice_regular_str
            get_all_components_list
            cd "$home_dir" || exit      
        done < "$project_file"
    else
        log_output 2 "项目${project_name}不存在"
    fi
    list_dir=${clean_path}/${project_name}
    if [ -d "$list_dir" ]; then 
        for name in $(ls "$list_dir")
        do
            generate_clean_info "${list_dir}"/"${name}"
        done
        cd "$home_dir" || exit
    else
        log_output 2 "项目路径不存在"
    fi
 }

#获取所有项目的清理信息
get_all_project_clean_info()
{
    local project_dir=${home_dir}/data
    ls "${project_dir}" | while read -r project
    do
        project_name=${project}
        get_single_project_clean_info
    done
}

#根据组件ID清理组件
delete_components_byID()
{
    curl -s -u "${nexus_user}":"${nexus_pwd}" -X 'DELETE' "${nexus_url}/service/rest/v1/components/${compent_id}" \
    -H 'accept: application/json'
    sleep 0.5
}

#执行清理操作
do_clean()
{
    if [ -d "$clean_path" ]; then
        find_deletefile=$(find "$clean_path" -type f -name "list.delete" | wc -l )
        if [ "$find_deletefile" -eq 0 ]; then
            log_output 1 "没有生成任何list.delete文件, 不做清理"
            exit
        else
            log_output 1 "开始进行文件清理,开始时间: $(date +%Y-%m-%d" "%H:%M:%S)"
            local delete_count
            delete_count=0
            start_time=$(date +%s)
            while read -r deletefile
            do
                while read -r list
                do
                    read -r d_id d_groupid d_artifacid d_version <<< "$(echo "$list" | awk '{ print $1,$2,$3,$4 }')"
                    compent_id=$d_id
                    delete_components_byID
                    delete_count=$(( delete_count + 1 ))
                    log_output 1 "清理版本信息: $d_groupid  $d_artifacid [version: $d_version]"
                done < "$deletefile"
            #此处必须使用here-strings方式传递数据，使用管道会创建子shell导致delete_count值无法传递到父shell
            done <<< "$(find "$clean_path" -type f -name "list.delete")" 
            end_time=$(date +%s)
            clean_times=$((end_time-start_time))
            local h
            h=$(echo "$clean_times/3600" | bc)
            local m
            m=$(echo "$((clean_times%3600))/60" |bc )
            local s
            s=$(echo "$clean_times%60" | bc)
            log_output 1 "清理完成，共清理 ${delete_count} 个包, 结束时间: $(date +%Y-%m-%d" "%H:%M:%S), 用时: ${h}小时${m}分钟${s}秒"
        fi
    else
        log_output 2 "${clean_path}清理信息不存在,无法清理"
        exit
    fi
}

#获取定时任务状态
get_task_state()
{
    task_state=$(curl -s -u "${nexus_user}":"${nexus_pwd}" -X 'GET' "${nexus_url}/service/rest/v1/tasks/${compcat_task_id}" \
    -H 'accept: application/json' | jq .currentState)
    echo "任务状态：$task_state"
}

#执行blob compcat定时任务，此任务是真正的将组件从磁盘清除
exec_blob_compcat_task()
{
    get_task_state
    if [ "$task_state" == "" ]
    then
        log_output 2 "Blob Compcat任务不存在"
    elif [ "$task_state" == "RUNNING" ]
    then
        log_output 3 "Blob Compcat清理任务正在运行, 请等待执行完成后重新手动执行。"
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

#获取当前的时间使用此时间创建一次清理的目录
generate_clean_path()
{   
    if [ ! -d "${clean_path}" ];
    then
        timestring=$(date +%Y%m%d%H%M%S)
        clean_path=$(pwd)/jsondata/${timestring}
        log_output 1 "----------------------------任务开始-----------------------------------------"
        log_output 1 "生成本次任务执行临时目录: ${clean_path}"
    fi
}

#获取磁盘使用率
# get_disk_usage()
# {
#     df -h $1 | tail -1  | awk '{ print "总量:" $2, "已使用:" $3, "可用:" $4, "使用率:" $5}'
# }

#####################功能使用说明##################################################
# 功能1：获取或清理指定groupID下面的包
#       sh nexus_clean.sh [-d] -g 'com.th.supcom.portal|xxx|xxxx'
# 功能2：获取或清理指定项目下面所有包
#       sh nexus_clean [-d] -p "TJH,TJXN"
# 功能3：获取或清理所有项目
#       sh nexus_clean [-d] --all
# 功能4：指定清理某个生成目录下面的包
#       sh nexus_clean -d --time 20240702151357
####################相关条件和限制说明##############################################
# 1、-d 是可选项， 加入-d,表示要进行清理操作，不加-d表示只做查询
# 2、-g 表示group , -p 表示project  ，此两个参数不能一起用
# 3、--all 表示，直接扫描data目录下面的所有项目
# 4、如果只清理已存生成的清理信息，使用-d 然后使用 --time参数，指定时间点所表示的目录
# 5、-d 选项和--time选项不能单独使用
###################################################################################

#set -e

#运行过程中，如果安装了ctr+c终止进程，需要删除已经生成的文件
#trap 'rm -rf ${clean_path}' INT

home_dir=$(pwd)

#使用getopt格式化选项参数
ARGS=$(getopt -o g:p:d -l all,time: -- "$@")

if [ $? -ne 0 ]; then
  echo "无效的选项参数"
  exit 1
fi

if [ $# -eq 0 ]
    then
        ech
        o "请输入参数"
        exit
fi

if [ $# -eq 2 ]
then
    if [[ "$1" == "--time" || "$1" == "-d" ]]; then
        echo "$1 参数不能单独使用 (使用方法： -d --time xxxxx)"
        exit
    fi
fi

if [[ $# -eq 1  && "$1" == "-d" ]]; then
    echo "-d 参数不能单独使用"
    exit
fi

if [[ $ARGS == *"-p"* &&  $ARGS == *"-g"* ]]
then
    echo "-p参数和-g参数不能一起使用"
    exit
fi

if [[ $ARGS == *"--all"* && $ARGS == *"-p"* ||  $ARGS == *"--all"* && $ARGS == *"-g"*  ]]
then
    echo "--all参数和-p参数、-g参数不能一起使用"
    exit
fi

eval set -- "${ARGS}"

#删除标志
delete_tag=0

#遍历选项和参数
while [ -n "$1" ]
do
    case "$1" in 
        -g) groupinfo=$2
            #正则匹配验证，避免输入错误指令导致误删
            echo "$groupinfo" | grep -qP '^[^|]*\|[^|]*\|[^|]*$'
            if [ $? -eq 0 ]; then
                groupid=$(echo "$groupinfo" | cut -d '|' -f 1 )
                artifacid=$(echo "$groupinfo" | cut -d '|' -f 2 )
                areacode=$(echo "$groupinfo" | cut -d '|' -f 3 )
                if [ "$groupid" == "" ]; then
                    log_output 2 "参数不符合要求,groupid不能为空,程序退出...." 
                    exit
                else
                    generate_clean_path
                    get_single_groupID_clean_info
                fi
            else
                log_output 2 "参数不符合要求, 参数格式: groupid|artifacid|areacode, 程序退出...."
                exit
            fi
            shift
        ;;
        -p) projectinfo="$2"
            echo "$projectinfo" | grep -qE '^([A-Z]+,?)+[A-Z]+$' 
            if [ $? -eq 0 ]; then
                generate_clean_path
                IFSOLD=$IFS
                IFS="," read -ra arr <<< "$projectinfo"
                for project_name in  "${arr[@]}"
                do
                    echo "project_name: $project_name"
                    get_single_project_clean_info
                done
                IFS=$IFSOLD
            else
                log_output 2 "参数不符合要求, 参数格式: TJH,HNSZL, 程序退出...."
                exit
            fi
            shift
            ;;
        --all)  
            log_output 1 "生成本次任务执行临时目录: ${clean_path}"  
            get_all_project_clean_info
            shift
            ;;
        -d) delete_tag=1
        ;;
        --time) timestring=$2
                clean_path=$(pwd)/jsondata/${timestring}
                if [ -d "$clean_path" ]; then
                    log_output 1 "清理目录已存在"
                else
                    log_output 2 "清理目录不存在"
                    exit
                fi
                shift
        ;;
        --) shift 
            break;
        ;;
        *) echo "$1 参数不正确";;
    esac
    shift
done

if [ $delete_tag -eq 1 ]; then
    log_output 1 "检测到-d参数, 需要执行文件清理"
    do_clean
    if [ $? -eq 0 ]; then
        log_output 1 "文件清理已经完成, 启动 Nexus Blob Compact定时任务"
        exec_blob_compcat_task
    else
        log_output 2 "文件清理失败"
    fi
else
    log_output 1 "没有检测到-d参数,本次任务只查询出需要清理信息,未做真正清理操作"
fi