# VUXPCAP-1521 — Письма об ошибках и статусах XBRL-CSV

Сервис: `gmap2-vux-xbrl-csv-orchestrator` (+ доработки `gmap2-vux-db-facade` и GP).
Эпик: Q4 XBRL-CSV. Связанные: VUXPCAP-1443 (аналитика рассылки), VUXPCAP-1454 (задача от Миши — содержание уточнить).
Образец реализации: письмо с протоколом обычного XBRL в `gmap2-vux-ecm` (`OrchestratorService.sendHtmlMail` + `xbrl_protocol.ftl`).

---

## 1. Постановка

**Jira (цитата по смыслу):** доработать рассылку писем по XBRL-CSV. В письме нужно видеть `task_id`, `slice_id`,
номер и описание ошибки и т.д. — по аналогии с обычным XBRL.

**Confluence «7. Письма XBRL-CSV» (pageId=19442896818), граф процесса:**

Оркестратор раз в 15 минут читает `v_vux_xbrl_csv_task_mail`. Нет данных → ждём следующего цикла. Есть данные → ветвление по `status`:

| status | Где ошибка | Кому письмо | После отправки |
|---|---|---|---|
| 2 | интеграционный слой | только поставщикам, у которых есть ошибки | время отправки → `t_vux_xbrl_csv_task_mail.sent` |
| 4 | слой агрегации | всем поставщикам | то же |
| 6 | слой нарезки | команде ВУИКС | то же |

Справочник статусов `t_adm_xbrl_csv_task_status_dic`: 1 готов к проверке; 2 ошибки в интеграционном слое; 3 без ошибок в интеграционном слое; 4 ошибки в слое агрегации; 5 без ошибок в слое агрегации; 6 ошибки в слое нарезки; 7 без ошибок в слое нарезки; 9 задачи в СУПЗ созданы.

Таблицы, упомянутые аналитиком: `v_vux_xbrl_csv_task_mail` (вьюха для чтения), `t_vux_xbrl_csv_task`, `t_adm_xbrl_csv_check_level_dic`, `t_adm_xbrl_csv_task_status_dic`, `t_adm_xbrl_csv_provider`, `t_adm_xbrl_csv_email_settings`, `t_vux_xbrl_csv_check_error` (внутренние ошибки), `t_vux_xbrl_csv_check_result` (результаты проверок ЦБ).

**Страница помечена «в работе», два блокера на стороне БД:**
1. ждём поле, по которому можно соединить таблицы и взять ошибки;
2. ждём поле с шаблонами писем.

Шаблон-образец: «2.2 Протокол — группировка по объекту проверки» (обычный XBRL).

---

## 2. Что реализовано сейчас (as-is, проверено по коду)

### 2.1 gmap2-vux-xbrl-csv-orchestrator

| Компонент | Что делает |
|---|---|
| `XbrlCsvScheduler.processXbrlCsv()` | fixed-delay 15 мин: `fnLoadXbrlCsvTask` → `fnProcessXbrlCsv` → `fnPrepareXbrlCsv` → `XbrlCsvPipeline.run()`; в `finally` — `fnFlowXbrlCsvDone` |
| `XbrlCsvPipeline.run()` | 1-й шаг — `XbrlCsvMailProcessor.processMailNotifications()`, далее сборка файлов, ЕСМ, СУПЗ |
| `XbrlCsvMailProcessor` | читает `vuxXbrlCsvTaskMailRepository` (весь набор, `size=Integer.MAX_VALUE`), на каждую запись — одно письмо + `fnFlowXbrlCsvMailSend(uuid)` |
| `MailService` | SMTP, UTF-8, To/Cc, HTML-тело, префикс темы `Stand: <stand>. <app>: `, маскирование адресов в логах |
| `XbrlCsvTaskMailDto` | `uid, taskId, provId, provName, status, statusName, levelName, isError, flagIgnoreError, repStartDate, repEndDate, mailList, mailListCopy` |

Текущее письмо — **захардкоженная строка** в `buildBody()`:
- тема: `Задача '<taskId>' завершена с ошибкой! Требуется проверить данные` (при null — `taskId is null!!`);
- тело: одна фраза + `<li>Идентификатор задачи</li>` + `<li>uid</li>`.

Никаких данных об ошибках, поставщике, периоде, уровне проверки в письмо не попадает, хотя `provName`, `statusName`, `levelName`, `repStartDate/EndDate` в DTO уже есть.

### 2.2 gmap2-vux-db-facade

- `VuxXbrlCsvTaskMailEntity` → `v_vux_xbrl_csv_task_mail`, `@Id uid`.
- Определение вьюхи (`docs/add_xbrl_csv_pipeline/tables.md` оркестратора): `t_vux_xbrl_csv_task_mail tm` JOIN `t_vux_xbrl_csv_task` JOIN `check_level_dic` JOIN `task_status_dic` LEFT JOIN `provider`, `WHERE tm.sent IS NULL AND ts.disabled = 0`.
- **Нет** сущностей/репозиториев для `t_vux_xbrl_csv_check_error`, `t_vux_xbrl_csv_check_result`, `t_adm_xbrl_csv_email_settings`, `t_adm_xbrl_csv_provider`. В `request.json` (enum `repository`) их тоже нет.
- Процедура `fnFlowXbrlCsvMailSend(uuid)` зарегистрирована.

### 2.3 gmap2-vux-ecm (образец для «как в обычном XBRL»)

- `FreemarkerConfig` → `classpath:/templates/`, UTF-8.
- `FreemarkerResolverService` кэширует `xbrl_protocol.ftl` в `@PostConstruct`, модель `ProtocolModelDto` (`documentNumber, documentDate, reportType, checkDate, objects, warnings, checksList, totalErrorCount, totalWarningCount`).
- `OrchestratorService.sendHtmlMail()`: тема `XBRL \\ <formCode> Ошибки на отчетную дату: <date>`, тело = тот же HTML, что и PDF-протокол; после отправки — `flowSetMailStatus(...)`.
- Лимиты строк: `config.defects-limits.error-set:30`, `total-set:200` (выборка `findByDocIdWithRnLimit`), длина описания ошибки обрезается до 256 символов (`VuxDocumentValidationResultViewEntityMapper`).
- `EmailSchedulerService`: шаблоны `mail_reminder.ftl` / `mail_check_reminder.ftl`, выбор шаблона по enum `InfoEmailTypeEnum`, бизнес-письма без префикса стенда (`addPrefix=false`).

В других сервисах проекта (`gmap2-vux-ui`, `gmap2-vux-gp-logger`, `curcontrol-*`) почтовых шаблонов нет. Единственный источник паттерна — `gmap2-vux-ecm`.

---

## 3. Расхождения аналитики и кода (найдено при сверке)

1. **Нет ветвления по статусу.** Граф в Confluence разделяет 2 / 4 / 6 по получателям и содержанию; код шлёт одно и то же письмо на любую запись.
2. **Письмо помечается отправленным, даже если не ушло.** `MailService.sendMail` глотает `MailException`, тихо выходит при пустых `MAIL_USER/MAIL_PASSWORD` и при пустом списке получателей, а `XbrlCsvMailProcessor` после этого всё равно вызывает `fnFlowXbrlCsvMailSend` → запись пропадает из вьюхи навсегда. В ECM то же поведение. Нужно решение (см. вопрос 10).
3. **Нет HTML-экранирования.** Тексты ошибок из БД вставляются как есть (в `xbrl_protocol.ftl` тоже). Текст вида `<enum=...>` сломает вёрстку. В новых шаблонах — `<#ftl output_format="HTML">`.
4. **Разделитель адресов.** Оркестратор режет `mail_list` по `,`, ECM — по `;`, `EmailSchedulerService` — по тому, что встретится. Формат в `t_adm_xbrl_csv_email_settings` нужно зафиксировать.
5. **Устаревшая документация.** `pipeline-scheme.md`, прим. 2: «почтовый шаг при `mail.enabled=false` бросает исключение и прерывает пайплайн» — в коде уже не так (шаг логирует WARN и пропускается).
6. **Опечатка в паспорте сервиса.** Сценарий 2, п.4 — `v_vux_xbrl_task_email`; реальное имя — `v_vux_xbrl_csv_task_mail`.
7. **Спека `xbrl-csv-notifications` допускает несколько записей с одним `uid`**, но в db-facade у сущности `@Id uid`. Если вьюха вернёт дубли `uid`, Hibernate склеит их в один объект. Нужно подтвердить, что `uid` уникален во вьюхе.
8. **В оркестраторе нет FreeMarker** (`pom.xml`: только `spring-boot-starter-mail`).
9. **Префикс темы** `Stand: PROD. gmap2-vux-xbrl-csv-orchestrator: ...` уходит бизнес-получателям. В ECM для бизнес-писем префикс отключён.

---

## 4. Вопросы к аналитику (Гришаков В.В.) и разработчику БД

**Данные об ошибках — главный блокер**

1. Откуда брать ошибки для письма: `t_vux_xbrl_csv_check_error`, `t_vux_xbrl_csv_check_result` или обе? Для каких статусов какая таблица?
2. Какое поле связывает запись письма с ошибками: `uid` письма, `task_id + prov_id + check_level`, `slice_id`? Когда оно появится (блокер №1 на странице)?
3. Структура таблиц ошибок: есть ли код ошибки, описание, раздел (`chapter_code`), колонка, ключ строки/объекта (`deal_id`, `client_id`, `row_id`…), `prov_id`, `slice_id`, признак E/W, количество?
4. Можно ли сделать отдельную вьюху `v_vux_xbrl_csv_task_mail_error` (одна строка = одна ошибка, с `uid` письма и `rn` для лимита), по аналогии с `v_vux_document_validation_result`? Оркестратор только читает, поэтому сборка через вьюху предпочтительнее, чем джойны на стороне Java.
5. Нужна ли сводка по видам проверок (как `v_vux_document_validation_log` → таблица «Результат проверки» в протоколе)? Если да — из какой таблицы и с какими полями.

**slice_id**

6. `slice_id` есть только для status = 6 (на 2 и 4 нарезки ещё нет)? Будет ли он в `t_vux_xbrl_csv_task_mail` / во вьюхе?

**Шаблоны и типы писем**

7. «Поле с шаблонами писем» (блокер №2) — это код типа письма (enum / ссылка на справочник), а тексты остаются в коде, как решили в VUXPCAP-774 («хардкод: один шаблон + атрибуты»)? Или в БД будут храниться тема/тело? Предлагаю: `mail_type smallint` (1 = поставщику, 2 = всем поставщикам, 3 = команде ВУИКС), шаблоны — `.ftl` в ресурсах.
8. Если поля типа не будет — можно ли выбирать шаблон по `status` (2/4/6)?

**Получатели**

9. Кто формирует `mail_list` / `mail_list_copy` — БД на основе `t_adm_xbrl_csv_email_settings` по `prov_id`? Для status = 4 «всем поставщикам» — одна запись с общим списком или по записи на поставщика? Для status = 6 — адрес команды ВУИКС откуда? Разделитель — `,` или `;`?

**Поведение**

10. Если письмо не ушло (SMTP недоступен, нет получателей, нет кредов) — вызывать `fnFlowXbrlCsvMailSend` или оставить запись во вьюхе для повтора в следующем цикле? Нужен ли лимит повторов?
11. `flag_ignore_error = 1`: письмо слать? С каким текстом (ошибка или предупреждение)?
12. Сколько ошибок показывать в письме (в ECM — 30 ошибок / 200 всего)? Нужно ли прикладывать полный перечень (CSV/XLSX) или ссылку?
13. Формат темы, нужен ли префикс стенда, формат дат (`dd.MM.yyyy`?), часовой пояс.
14. Нужен ли, как в обычном XBRL, PDF-протокол в ЕСМ, или только письмо?
15. Блок контактов в подвале письма — кого указывать?
16. Что в VUXPCAP-1454 («задача от Миши»)? Её требования нужно учесть.

---

## 5. Целевое решение (to-be)

### 5.1 Поток

```
XbrlCsvMailProcessor.processMailNotifications()
  ├─ query vuxXbrlCsvTaskMailRepository                       (как сейчас)
  └─ для каждой записи:
       ├─ type = XbrlCsvMailType.resolve(record)              (по mail_type, fallback — по status)
       ├─ errors = query vuxXbrlCsvTaskMailErrorRepository     {uid}, sort rn, size = mail.errors-limit
       ├─ model  = XbrlCsvMailModelFactory.build(record, errors, type)
       ├─ html   = XbrlCsvMailTemplateService.render(type, model)
       ├─ subject= type.subject(model)
       ├─ sent   = mailService.sendMail(subject, html, to, cc, false)   ← возвращает boolean
       └─ if sent → fnFlowXbrlCsvMailSend(uuid)                ← только при успехе (если подтвердят, вопрос 10)
```

Пока вопросы 1–4 не закрыты, работает вариант 1 (базовый шаблон на текущих полях), остальные шаблоны получают пустые `errors` и деградируют корректно (таблицы не рисуются).

### 5.2 Типы писем и шаблоны

| Тип (enum `XbrlCsvMailType`) | status | Шаблон | Тема |
|---|---|---|---|
| `BASIC` | любой / fallback | `xbrl_csv_error_basic.ftl` | `XBRL-CSV \\ Задача {taskId}: ошибки, уровень «{levelName}», период {start}–{end}` |
| `PROVIDER` | 2 | `xbrl_csv_error_provider.ftl` | `XBRL-CSV \\ {provName}: ошибки в данных по задаче {taskId} за {start}–{end}` |
| `AGGREGATION` | 4 | `xbrl_csv_error_aggregation.ftl` | `XBRL-CSV \\ Ошибки агрегации по задаче {taskId}, формирование пакета остановлено` |
| `SLICE` | 6 | `xbrl_csv_error_slice.ftl` | `[ВУИКС] XBRL-CSV \\ Ошибки нарезки пакетов по задаче {taskId}` |

Общие макросы — `xbrl_csv_mail_common.ftl` (стили, шапка, блок метаданных, таблица проверок, таблица ошибок, подвал).
Все шаблоны — `<#ftl output_format="HTML">` (авто-экранирование), табличная вёрстка (Outlook).

### 5.3 Модель шаблона (`XbrlCsvMailModel`)

| Поле | Тип | Источник | Есть сейчас |
|---|---|---|---|
| `uid` | String | вьюха | да |
| `taskId` | String | вьюха | да |
| `provId`, `provName` | String | вьюха | да |
| `status`, `statusName`, `levelName`, `isError` | Short / String | вьюха | да |
| `flagIgnoreError` | boolean | вьюха (`== 1`) | да |
| `repStartDate`, `repEndDate` | String `dd.MM.yyyy` | вьюха | да |
| `checkDate` | String `dd.MM.yyyy HH:mm:ss` | `LocalDateTime.now()` | — |
| `sliceId` | String | вьюха | **нет** |
| `requestNumber`, `srcTaskId`, `deadline` | String | `t_vux_xbrl_csv_task` (добавить во вьюху) | **нет** |
| `errors[]` | `{sliceId, provName, chapter, objectKey, column, errorCode, errorMessage}` | вьюха ошибок | **нет** |
| `checks[]` | `{code, name, count}` | сводка проверок | **нет** |
| `totalErrorCount` | long | вьюха ошибок / сводка | **нет** |
| `providers[]` (тип 4) | `{provId, provName, errorCount}` | группировка `errors` по поставщику | **нет** |
| `slices[]` (тип 6) | `{sliceId, sliceNum, version, startDate, endDate, errorCount}` | `t_vux_xbrl_csv_slice` + группировка | **нет** |
| `contacts[]` | `{name, email}` | конфиг `mail.contacts` | — |

---

## 6. ТЗ для GigaCode (пошагово)

> Контекст для агента: Spring Boot, Java 21+, Lombok, Feign-клиент к db-facade (`DbFacadeClient`, `DbFacadeRequestBuilder`),
> DTO-records с `@JsonIgnoreProperties(ignoreUnknown = true)`, логи на английском с префиксом `[MAIL STEP]`,
> адреса и ПДн в лог не писать. Стиль — как в существующих классах пакета `ru.sbrf.gmap.vux.orchestra.csv`.
> Образец шаблонизатора — `gmap2-vux-ecm`: `FreemarkerResolverService`, `EmailSchedulerService`, `templates/xbrl_protocol.ftl`.

### Этап A — можно делать сейчас (без доработок БД)

**A1. FreeMarker в оркестраторе**
- `service/pom.xml`: добавить `org.freemarker:freemarker` (версию — из BOM Spring Boot, без явного номера, если BOM её даёт).
- `config/FreemarkerConfig`: бин `freemarker.template.Configuration` — `ClassTemplateLoader(getClass(), "/templates")`, `defaultEncoding=UTF-8`, `TemplateExceptionHandler.RETHROW_HANDLER`, `logTemplateExceptions=false`, `recognizeStandardFileExtensions=true`.
- Положить в `service/src/main/resources/templates/` файлы `xbrl_csv_mail_common.ftl`, `xbrl_csv_error_basic.ftl` (приложены).

**A2. Сервис шаблонов**
- `service/XbrlCsvMailTemplateService`: в `@PostConstruct` загрузить и закэшировать шаблоны в `EnumMap<XbrlCsvMailType, Template>`; при ошибке загрузки — `IllegalStateException` (fail-fast, как в ECM).
- `String render(XbrlCsvMailType type, Map<String,Object> model)`; `TemplateException`/`IOException` → `IllegalStateException` с именем шаблона.

**A3. Модель и тип письма**
- `mail/XbrlCsvMailType` (enum): `BASIC, PROVIDER, AGGREGATION, SLICE`; поля `templateName`, метод `subject(model)`; `static resolve(XbrlCsvTaskMailDto)` — пока всегда `BASIC` (переключение по `status` — этап B).
- `mail/XbrlCsvMailModelFactory`: собирает `Map<String,Object>` из `XbrlCsvTaskMailDto` (поля из таблицы 5.3, даты `dd.MM.yyyy`, `flagIgnoreError` → boolean, `checkDate`). `null` не класть в map (шаблоны работают через `!`).
- `config/MailProps` или новый `XbrlCsvMailProperties`: `mail.contacts` (список name/email), `mail.errors-limit` (default 30), `mail.subject-prefix` (default false).

**A4. Переделать `XbrlCsvMailProcessor`**
- Удалить `buildBody()` и строковую тему; использовать `XbrlCsvMailType`, фабрику модели и сервис шаблонов.
- `mailService.sendMail(subject, html, to, cc, props.subjectPrefix())`.
- Если `mailList` пустой — WARN `[MAIL STEP] no recipients for uid='{}'`, письмо не слать, `fnFlowXbrlCsvMailSend` **не** вызывать (до ответа на вопрос 10 — согласовать).

**A5. Результат отправки**
- `MailService.sendMail(...)` → возвращает `boolean` (true — `javaMailSender.send` прошёл). Существующие вызовы (`MailStartupTestRunner`) поправить.
- В процессоре вызывать `fnFlowXbrlCsvMailSend` только при `true` (после подтверждения вопроса 10; иначе оставить текущее поведение за флагом `mail.mark-sent-on-failure`).

**A6. Тесты**
- `XbrlCsvMailTemplateServiceTest`: рендер каждого шаблона на полной модели и на минимальной (только `uid`) без исключений; экранирование: `errorMessage = "<b>x</b>"` → в HTML `&lt;b&gt;`.
- `XbrlCsvMailProcessorTest`: обновить проверки темы (`contains(taskId)`), добавить кейсы «пустой mail_list → нет письма и нет процедуры», «sendMail=false → нет процедуры».
- `MailServiceTest`: возвращаемое значение.

### Этап B — после ответов БД (вопросы 1–9)

**B1. db-facade**
- Сущность + репозиторий для вьюхи ошибок (рабочее имя `v_vux_xbrl_csv_task_mail_error`, `@IdClass` по естественному ключу, не по `uid`).
- При появлении — добавить в `VuxXbrlCsvTaskMailEntity` поля `slice_id`, `mail_type`, `request_number`, `src_task_id`, `deadline`.
- Добавить имена репозиториев в enum `repository` схемы `request.json`; changelog для H2 (как `changelog-006`), тесты схемы.

**B2. Оркестратор**
- Синхронизировать `schema.v1/request.json` с db-facade.
- `XbrlCsvMailErrorDto` (record) + чтение ошибок: `requestBuilder.query(VUX_XBRL_CSV_TASK_MAIL_ERROR_REPOSITORY, filter{uid}, sort rn asc, 0, errorsLimit)`.
- `XbrlCsvMailType.resolve`: по `mailType`, fallback по `status` (2 → PROVIDER, 4 → AGGREGATION, 6 → SLICE, иначе BASIC).
- Фабрика модели: `errors`, `checks`, `totalErrorCount`, `providers` (group by `provId`), `slices`; обрезка `errorMessage` до 256 символов + `...` (как в ECM).
- Добавить шаблоны `xbrl_csv_error_provider.ftl`, `_aggregation.ftl`, `_slice.ftl`.

**B3. Документация**
- Обновить `openspec/specs/xbrl-csv-notifications/spec.md` (типы писем, шаблоны, правило фиксации отправки).
- Поправить `docs/add_xbrl_csv_pipeline/pipeline-scheme.md` (прим. 2) и `tables.md` (новая вьюха).

### Критерии приёмки

- Письмо по записи `v_vux_xbrl_csv_task_mail` содержит: task_id, поставщика, период, уровень проверки, статус (этап A); + slice_id, список ошибок с кодом и описанием, «показано N из M» (этап B).
- Для status 2 / 4 / 6 используются разные шаблоны и темы.
- Спецсимволы в текстах ошибок не ломают вёрстку.
- Письмо, которое не ушло, не помечается отправленным (если подтверждено).
- В логах нет адресов и ПДн; все существующие тесты зелёные.

---

## 7. Приложенные файлы

- `templates/xbrl_csv_mail_common.ftl` — общие макросы.
- `templates/xbrl_csv_error_basic.ftl` — вариант 1, работает на текущей вьюхе.
- `templates/xbrl_csv_error_provider.ftl` — вариант 2, status = 2.
- `templates/xbrl_csv_error_aggregation.ftl` — вариант 3, status = 4.
- `templates/xbrl_csv_error_slice.ftl` — вариант 4, status = 6.

Все шаблоны прогнаны через FreeMarker 2.3.28 на тестовых данных (полная модель, модель без `taskId`/поставщика, текст ошибки с `<...>`) — рендерятся без ошибок, экранирование работает.
