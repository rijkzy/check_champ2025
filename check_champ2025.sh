#!/bin/bash

# Название скрипта
SCRIPT_NAME="check_champ2025"
VERSION="1.0"
AUTHOR="Your Name"
GITHUB_REPO="https://github.com/yourusername/check_champ2025"

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Файл для логирования
LOG_FILE="check_champ2025.log"

# Функция для вывода заголовка
print_header() {
    echo -e "${BLUE}"
    echo "============================================"
    echo " $SCRIPT_NAME - Version $VERSION"
    echo " Author: $AUTHOR"
    echo " GitHub: $GITHUB_REPO"
    echo "============================================"
    echo -e "${NC}"
}

# Функция для вывода сообщения об ошибке
print_error() {
    echo -e "${RED}[ERROR] $1${NC}"
}

# Функция для вывода сообщения об успехе
print_success() {
    echo -e "${GREEN}[SUCCESS] $1${NC}"
}

# Функция для вывода информационного сообщения
print_info() {
    echo -e "${YELLOW}[INFO] $1${NC}"
}

# Функция для запроса VM ID
get_vm_id() {
    local vm_name=$1
    while true; do
        read -p "Введите VM ID для $vm_name: " vm_id
        if [[ $vm_id =~ ^[0-9]+$ ]]; then
            echo $vm_id
            break
        else
            print_error "Некорректный VM ID. Пожалуйста, введите число."
        fi
    done
}

# Функция для проверки выполнения пункта и добавления баллов
check_and_add_score() {
    local description=$1
    local score=$2
    local command=$3

    echo -e "${BLUE}Проверка: $description${NC}"
    if eval $command; then
        print_success "Выполнено. Баллы: $score"
        total_score=$((total_score + score))
    else
        print_error "Не выполнено. Баллы: 0"
    fi
    echo ""
}

# Логирование результатов
log_result() {
    local message=$1
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $message" >> $LOG_FILE
}

# Основная функция
main() {
    print_header

    # Запрос VM ID для каждой машины
    print_info "Введите VM ID для каждой машины:"
    R_DT=$(get_vm_id "R-DT")
    R_HQ=$(get_vm_id "R-HQ")
    SRV1_HQ=$(get_vm_id "SRV1-HQ")
    SRV1_DT=$(get_vm_id "SRV1-DT")
    SW1_HQ=$(get_vm_id "SW1-HQ")
    SW2_HQ=$(get_vm_id "SW2-HQ")
    SW3_HQ=$(get_vm_id "SW3-HQ")
    FW_DT=$(get_vm_id "FW-DT")

    # Инициализация переменных для хранения баллов
    total_score=0

    # Проверка базовой настройки
    check_and_add_score "Настройка полных доменных имен" 0.3 "pvesh get /nodes/localhost/qemu/$SRV1_HQ/config | grep -q 'name:'"
    check_and_add_score "Адресация офиса HQ" 0.4 "pvesh get /nodes/localhost/qemu/$R_HQ/config | grep -q 'ipconfig0'"
    check_and_add_score "Адресация офиса DT" 0.3 "pvesh get /nodes/localhost/qemu/$R_DT/config | grep -q 'ipconfig0'"
    check_and_add_score "Адресация туннеля" 0.4 "pvesh get /nodes/localhost/qemu/$R_HQ/config | grep -q 'ipconfig1'"
    check_and_add_score "Создание пользователя sshuser" 0.5 "pvesh get /nodes/localhost/qemu/$SRV1_HQ/config | grep -q 'sshuser'"
    check_and_add_score "Пользователь sshuser может запускать sudo без пароля" 0.8 "pvesh get /nodes/localhost/qemu/$SRV1_HQ/config | grep -q 'NOPASSWD'"
    check_and_add_score "Пользователь sshuser на маршрутизаторах имеет максимальные права" 0.8 "pvesh get /nodes/localhost/qemu/$R_HQ/config | grep -q 'ALL=(ALL) ALL'"

    # Проверка настройки коммутации
    check_and_add_score "Установка Open vSwitch на SW1-HQ, SW2-HQ, SW3-HQ" 0.4 "pvesh get /nodes/localhost/qemu/$SW1_HQ/config | grep -q 'openvswitch'"
    check_and_add_score "Создание коммутатора с правильным именем" 0.4 "pvesh get /nodes/localhost/qemu/$SW1_HQ/config | grep -q 'SW1-HQ'"
    check_and_add_score "Порты переданы в управление Open vSwitch" 0.4 "pvesh get /nodes/localhost/qemu/$SW1_HQ/config | grep -q 'eth0'"
    check_and_add_score "Настройка STP, корень SW1-HQ" 0.8 "pvesh get /nodes/localhost/qemu/$SW1_HQ/config | grep -q 'stp_enable=true'"

    # Проверка настройки подключения маршрутизаторов к провайдеру
    check_and_add_score "Подключение R-DT к провайдеру" 0.4 "pvesh get /nodes/localhost/qemu/$R_DT/config | grep -q '172.16.4.0/28'"
    check_and_add_score "Подключение R-HQ к провайдеру" 0.4 "pvesh get /nodes/localhost/qemu/$R_HQ/config | grep -q '172.16.5.0/28'"

    # Проверка настройки NAT
    check_and_add_score "Настройка NAT для офисов" 0.8 "pvesh get /nodes/localhost/qemu/$R_HQ/config | grep -q 'MASQUERADE'"

    # Проверка настройки DHCP
    check_and_add_score "Настройка DHCP CLI на R-HQ" 0.8 "pvesh get /nodes/localhost/qemu/$R_HQ/config | grep -q 'dhcpd'"
    check_and_add_score "Настройка DHCP CLI на R-DT" 0.8 "pvesh get /nodes/localhost/qemu/$R_DT/config | grep -q 'dhcpd'"

    # Проверка настройки GRE и OSPF
    check_and_add_score "Настройка GRE между DT и HQ" 0.8 "pvesh get /nodes/localhost/qemu/$R_HQ/config | grep -q 'gre'"
    check_and_add_score "Настройка OSPF over GRE между DT и HQ" 0.5 "pvesh get /nodes/localhost/qemu/$R_HQ/config | grep -q 'ospf'"
    check_and_add_score "Настройка OSPF между R-DT и FW-DT" 0.5 "pvesh get /nodes/localhost/qemu/$R_DT/config | grep -q 'ospf'"

    # Проверка настройки DNS
    check_and_add_score "Настройка DNS на SRV1-HQ" 1 "pvesh get /nodes/localhost/qemu/$SRV1_HQ/config | grep -q 'example.com'"
    check_and_add_score "Резервный DNS на SRV1-DT" 1 "pvesh get /nodes/localhost/qemu/$SRV1_DT/config | grep -q 'example.com'"

    # Проверка настройки NTP
    check_and_add_score "Настройка NTP сервера на SRV1-HQ" 0.5 "pvesh get /nodes/localhost/qemu/$SRV1_HQ/config | grep -q 'ntp2.vniiftri.ru'"
    check_and_add_score "Синхронизация времени с SRV1-HQ" 0.8 "pvesh get /nodes/localhost/qemu/$SRV1_HQ/config | grep -q 'chrony'"

    # Проверка настройки SAMBA AD
    check_and_add_score "Настройка SAMBA AD на SRV1-HQ" 1.5 "pvesh get /nodes/localhost/qemu/$SRV1_HQ/config | grep -q 'samba'"
    check_and_add_score "Резервный контроллер домена SRV1-DT" 1 "pvesh get /nodes/localhost/qemu/$SRV1_DT/config | grep -q 'samba'"

    # Вывод общего балла
    echo -e "${BLUE}============================================${NC}"
    echo -e "${GREEN}✅ Общий балл: $total_score${NC}"
    echo -e "${BLUE}============================================${NC}"

    # Логирование результатов
    log_result "Общий балл: $total_score"
}

# Запуск основной функции
main
