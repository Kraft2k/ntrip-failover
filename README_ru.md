# OpenWrt NTRIP Failover Script

Этот скрипт решает проблему стабильности NTRIP-клиента на роутерах c OS OpenWrt. Он позволяет указать несколько базовых станций и автоматически переключается между ними, если одна из них уходит в оффлайн.

## Особенности
- Авто-переключение: Мониторинг потока данных в реальном времени.
- Детекция SOURCETABLE: Мгновенный пропуск неактивных станций.
- Ротация логов: Предотвращает переполнение оперативной памяти.
- Интеграция с UCI: Настройки берутся напрямую из конфига роутера.

## Установка (Manual)
1. Переименуйте бинарник ntripclient: mv /usr/bin/ntripclient /usr/bin/ntripclient.exe
2. Скопируйте ntrip-stream.sh в /usr/bin/
3. Дайте права: chmod +x /usr/bin/ntrip-stream.sh

## Настройка
Добавьте ваши станции в /etc/config/ntrip:
```bash
config client
    option mountpoint 'MOUNT_1 MOUNT_2'
```


## Инструкция по установке и настройке IPK
### 1. Установка пакета
Перенесите файл пакета на роутер (например, через SCP) и выполните установку:

Копирование (выполняется на ПК)
```bash
scp ntrip-failover-plus_1.0.0_mipsel_24kc.ipk root@192.168.1.1:/tmp/
```
Установка (выполняется на роутере)
```bash
opkg install /tmp/ntrip-failover-plus_1.0.0_mipsel_24kc.ipk
```
Пакет автоматически создаст конфиг, переименует бинарник и настроит автозапуск.

### 2. Настройка конфигурации
Все настройки хранятся в файле /etc/config/ntrip. Вы можете отредактировать его вручную через vi:

```bash
vi /etc/config/ntrip
```

Или используя команды uci (рекомендуется):

```bash
uci set ntrip.client.mountpoint='MOUNT1 MOUNT1'
uci set ntrip.client.server='my_server'
uci set ntrip.client.user='my_login'
uci set ntrip.client.password='my_pass'
uci commit ntrip
```
### 3. Управление сервисом
Скрипт работает как системная служба.

```bash
/etc/init.d/ntrip-stream restart  # Перезапуск после смены настроек
/etc/init.d/ntrip-stream stop     # Остановка
/etc/init.d/ntrip-stream start    # Запуск
```

### 4. Просмотр логов
Для отладки и мониторинга переключений используйте стандартный logread:

```bash
logread -f | grep ntrip-failover
```