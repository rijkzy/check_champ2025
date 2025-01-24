#!/bin/bash

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Функция для красивого вывода
print_header() {
    echo -e "${BLUE}"
    echo "============================================"
    echo " Система оценки Чемпионата 2025"
    echo " Версия 6.0"
    echo "============================================"
    echo -e "${NC}"
}

# Запрос VM ID для всех устройств
declare -A VM_IDS=()
get_vm_ids() {
    echo -e "${YELLOW}Введите VM ID для каждого устройства:${NC}"
    VM_IDS=(
        [R-DT]=$(read -p "R-DT: " val; echo $val)
        [R-HQ]=$(read -p "R-HQ: " val; echo $val)
        [SRV1-HQ]=$(read -p "SRV1-HQ: " val; echo $val)
        [SRV1-DT]=$(read -p "SRV1-DT: " val; echo $val)
        [SW1-HQ]=$(read -p "SW1-HQ: " val; echo $val)
        [SW2-HQ]=$(read -p "SW2-HQ: " val; echo $val)
        [SW3-HQ]=$(read -p "SW3-HQ: " val; echo $val)
        [FW-DT]=$(read -p "FW-DT: " val; echo $val)
        [SRV2-DT]=$(read -p "SRV2-DT: " val; echo $val)
        [SRV3-DT]=$(read -p "SRV3-DT: " val; echo $val)
        [ADMIN-DT]=$(read -p "ADMIN-DT: " val; echo $val)
        [CLI-DT]=$(read -p "CLI-DT: " val; echo $val)
        [ADMIN-HQ]=$(read -p "ADMIN-HQ: " val; echo $val)
        [CLI-HQ]=$(read -p "CLI-HQ: " val; echo $val)
        [SW-DT]=$(read -p "SW-DT: " val; echo $val)
        [CLI]=$(read -p "CLI: " val; echo $val)  # Новое устройство CLI
    )
}

# Функция проверки
check_score() {
    local desc="$1"
    local score="$2"
    local cmd="$3"
    
    echo -e "${BLUE}Проверка: ${desc}${NC}"
    if eval "$cmd"; then
        echo -e "${GREEN}✅ Успешно | Баллы: +${score}${NC}"
        total_score=$(awk "BEGIN {print $total_score + $score}")
    else
        echo -e "${RED}❌ Ошибка  | Баллы: 0${NC}"
    fi
    echo ""
}

# Основная логика
main() {
    total_score=0
    print_header
    get_vm_ids

    # Базовые настройки
    echo -e "${YELLOW}=== Базовые настройки ===${NC}"
    check_score "Полные доменные имена" 0.3 "pvesh get /nodes/localhost/qemu/${VM_IDS[SRV1-HQ]}/config | grep -q 'name:'"
    check_score "Адресация HQ" 0.4 "pvesh get /nodes/localhost/qemu/${VM_IDS[R-HQ]}/config | grep -q '192.168.11.0/24'"
    check_score "Адресация DT" 0.3 "pvesh get /nodes/localhost/qemu/${VM_IDS[R-DT]}/config | grep -q '192.168.33.0/24'"
    check_score "Создание пользователя sshuser" 0.5 "pvesh get /nodes/localhost/qemu/${VM_IDS[SRV1-HQ]}/config | grep -q 'sshuser'"
    check_score "Пользователь sshuser может запускать sudo без пароля" 0.8 "pvesh get /nodes/localhost/qemu/${VM_IDS[SRV1-HQ]}/config | grep -q 'sudo'"
    check_score "Пользователь sshuser на маршрутизаторах имеет максимальные права" 0.8 "pvesh get /nodes/localhost/qemu/${VM_IDS[R-HQ]}/config | grep -q 'privileges'"

    # Коммутация
    echo -e "${YELLOW}=== Настройка коммутации ===${NC}"
    check_score "Open vSwitch на SW1-HQ" 0.4 "pvesh get /nodes/localhost/qemu/${VM_IDS[SW1-HQ]}/config | grep -q 'openvswitch'"
    check_score "STP корень SW1-HQ" 0.8 "pvesh get /nodes/localhost/qemu/${VM_IDS[SW1-HQ]}/config | grep -q 'stp_enable=true'"
    check_score "VLAN на SW1-HQ" 0.5 "pvesh get /nodes/localhost/qemu/${VM_IDS[SW1-HQ]}/config | grep -q 'vlan110'"
    check_score "VLAN на SW2-HQ" 0.5 "pvesh get /nodes/localhost/qemu/${VM_IDS[SW2-HQ]}/config | grep -q 'vlan220'"
    check_score "VLAN на SW3-HQ" 0.5 "pvesh get /nodes/localhost/qemu/${VM_IDS[SW3-HQ]}/config | grep -q 'vlan330'"
    check_score "VLAN на SW-DT" 0.5 "pvesh get /nodes/localhost/qemu/${VM_IDS[SW-DT]}/config | grep -q 'vlan440'"

    # Маршрутизация
    echo -e "${YELLOW}=== Настройка маршрутизации ===${NC}"
    check_score "NAT для офисов" 0.8 "pvesh get /nodes/localhost/qemu/${VM_IDS[R-HQ]}/config | grep -q 'MASQUERADE'"
    check_score "GRE туннель" 0.8 "pvesh get /nodes/localhost/qemu/${VM_IDS[R-HQ]}/config | grep -q 'gre'"
    check_score "OSPF между R-DT и FW-DT" 0.5 "pvesh get /nodes/localhost/qemu/${VM_IDS[R-DT]}/config | grep -q 'ospf'"

    # Вывод промежуточных результатов
    echo -e "${BLUE}============================================${NC}"
    echo -e "${GREEN}Предварительный балл: ${total_score}${NC}"
    echo -e "${BLUE}============================================${NC}"
}

# Запуск первой части
main 2>&1 | tee -a evaluation.log
# Продолжение скрипта после первой части

    # DNS и NTP
    echo -e "${YELLOW}=== Службы инфраструктуры ===${NC}"
    check_score "Основной DNS" 1.0 "pvesh get /nodes/localhost/qemu/${VM_IDS[SRV1-HQ]}/config | grep -q 'bind9'"
    check_score "Резервный DNS" 1.0 "pvesh get /nodes/localhost/qemu/${VM_IDS[SRV1-DT]}/config | grep -q 'bind9'"
    check_score "NTP сервер" 0.5 "pvesh get /nodes/localhost/qemu/${VM_IDS[SRV1-HQ]}/config | grep -q 'ntp2.vniiftri.ru'"
    check_score "Все устройства синхронизируют время с SRV1-HQ" 0.8 "pvesh get /nodes/localhost/qemu/${VM_IDS[SRV1-HQ]}/config | grep -q 'ntp_sync=true'"

    # SAMBA AD
    echo -e "${YELLOW}=== Доменные службы ===${NC}"
    check_score "Контроллер домена" 1.5 "pvesh get /nodes/localhost/qemu/${VM_IDS[SRV1-HQ]}/config | grep -q 'samba'"
    check_score "Резервный контроллер" 1.0 "pvesh get /nodes/localhost/qemu/${VM_IDS[SRV1-DT]}/config | grep -q 'samba'"
    check_score "Общая папка SAMBA" 1.0 "pvesh get /nodes/localhost/qemu/${VM_IDS[SRV1-HQ]}/config | grep -q 'samba_share'"
    check_score "Клиенты введены в домен" 0.6 "pvesh get /nodes/localhost/qemu/${VM_IDS[CLI-DT]}/config | grep -q 'domain_joined=true'"

    # Вывод промежуточных результатов
    echo -e "${BLUE}============================================${NC}"
    echo -e "${GREEN}Промежуточный балл: ${total_score}${NC}"
    echo -e "${BLUE}============================================${NC}"
    # Продолжение скрипта после второй части

    # Docker и Zabbix
    echo -e "${YELLOW}=== Контейнеризация и мониторинг ===${NC}"
    check_score "Docker Registry" 1.0 "pvesh get /nodes/localhost/qemu/${VM_IDS[SRV2-DT]}/config | grep -q 'registry:2'"
    check_score "Zabbix сервер" 1.0 "pvesh get /nodes/localhost/qemu/${VM_IDS[SRV3-DT]}/config | grep -q 'zabbix-web'"
    check_score "Zabbix мониторинг" 0.8 "pvesh get /nodes/localhost/qemu/${VM_IDS[SRV3-DT]}/config | grep -q 'zabbix-agent'"
    check_score "Nginx reverse proxy" 1.0 "pvesh get /nodes/localhost/qemu/${VM_IDS[SRV1-DT]}/config | grep -q 'nginx'"

    # Вывод промежуточных результатов
    echo -e "${BLUE}============================================${NC}"
    echo -e "${GREEN}Промежуточный балл: ${total_score}${NC}"
    echo -e "${BLUE}============================================${NC}"
    # Продолжение скрипта после третьей части

    # Дополнительные сервисы
    echo -e "${YELLOW}=== Дополнительные сервисы ===${NC}"
    check_score "Ansible управление" 0.8 "pvesh get /nodes/localhost/qemu/${VM_IDS[ADMIN-DT]}/config | grep -q 'ansible'"
    check_score "Кибер Бекап" 1.0 "pvesh get /nodes/localhost/qemu/${VM_IDS[ADMIN-HQ]}/config | grep -q 'cyberbackup'"
    check_score "Резервное копирование на CLI-DT" 1.0 "pvesh get /nodes/localhost/qemu/${VM_IDS[CLI-DT]}/config | grep -q 'backup'"
    check_score "Резервное копирование на CLI-HQ" 1.0 "pvesh get /nodes/localhost/qemu/${VM_IDS[CLI-HQ]}/config | grep -q 'backup'"
    check_score "Резервное копирование на CLI" 1.0 "pvesh get /nodes/localhost/qemu/${VM_IDS[CLI]}/config | grep -q 'backup'"

    # Итоговый вывод
    echo -e "${BLUE}============================================${NC}"
    echo -e "${GREEN}Финальный балл: ${total_score}${NC}"
    echo -e "${BLUE}============================================${NC}"
    echo -e "${YELLOW}Лог проверок сохранен в evaluation.log${NC}"
}

# Запуск скрипта с записью лога
main 2>&1 | tee -a evaluation.log
