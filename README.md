# Random shell toolings / Произвольный инструментарий командной оболочки

<p> В данном репозитории собраны утилиты, разработанные мною в час нужды, решающие какие-либо специализированные задачи. </p>


## Указатель
<ul>
  <li> [s3_interaction_suite](#s3_interaction_suite) </li>
</ul>


## s3_interaction_suite

<p> Утилита для взаимодействия с AWS-S3-совместимым хранилищем (AWS S3, Yandex Cloud, Ceph, etc...). Для выполнения взаимодействия используется протокол HTTP. В ходе работы утилиты выполняется 1 запрос к S3 с указанными параметрами.</p>

<p>Требования: <p>
<ul>
  <li> ОС: debian-like linux - потому что на других ОС не тестировалось.</li>
  <li> bash - я не адаптировал скрипт под работу в sh и использую некоторые bash-only особенности. </li>
  <li> cURL / wget / netcat - в зависимости от выбранного бекенда (ключ -b). </li>
  <li> awk, base64, basename, cat, cut, getopts, head, logger, openssl, printf, tail, test, wc, [[ - нужны в целом для работы утилиты. </li>
</ul> 

<p> Ключи запуска </p>
<ul>
  <li>-b BACKEND: бэкенд для выполнения взаимодействия с S3. По умолчанию выбран OLDCURL. Варианты:
    <ul>
      <li> OLDCURL - для cURL версии 8.2 и ниже. </li>
      <li> CURL - для cURL версии 8.3 и выше. </li>
      <li> OPENSSL - для openssl. </li>
      <li> WGET - для gnu/wget </li>
      <li> NETCAT - для netcat (nc) </li>
    </ul>
  </li>
  <li>-r REQUEST: тип запроса к S3. Варианты:
    <ul>
      <li> GET - запрос получения объёкта с S3. </li>
      <li> HEAD - запрос проверки наличия объекта в S3. </li>
      <li> PUT - запрос загрузки объекта в S3. </li>
    </ul> 
  </li>
  <li>-f FQDN\IP: FQDN или IP ресурса S3 для подключения. </li>
  <li>-p PORT: порт удалённого подключения. По умолчанию выбран 443. </li>
  <li>-a access-key: Access-key учётной записи доступа к S3.</li>
  <li>-s secret-key: Secret-key учётной записи доступа к S3.</li>
  <li>(Опционально) -S signature: сигнатура подключения к S3.</li>
  <li>-o object-string: полный путь к объекту в S3-хранилище. </li>
  <li>(Опционально) -l local-path: локальный путь для сохранения\загрузки объекта. Используется в запросах GET, PUT. Лучше указывать абсолютный путь. </li>
  <li>-h : Вызов справки.</li>
</ul>

<p> Примеры запуска: </p>
<p> <code>./s3_interaction_suite.sh -b 'OLDCURL' -r 'GET' -f 's3.storage.ru' -a 'myaccesskeytos3' -s 'mysecretkeytos3' -o 'bucket/target/object/name'</code> - Получить файл с S3 с помощью OLDCURL и сохранить его с оригинальным именем.</p>
<p> <code>./s3_interaction_suite.sh -b 'WGET' -r 'PUT' -f 's3.storage.ru' -p 9000 -a 'myaccesskeytos3' -s 'mysecretkeytos3' -o 'bucket/target/object/name' -l '/path/to/upload/file'</code> - Загрузить локальный файл из указанного пути на S3 по порту 9000 с использованием WGET.</p>
