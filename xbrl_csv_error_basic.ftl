<#ftl output_format="HTML" encoding="UTF-8">
<#import "xbrl_csv_mail_common.ftl" as c>
<#--
  Вариант 1. «Базовое» письмо — работает на ТЕКУЩЕЙ витрине v_vux_xbrl_csv_task_mail
  без доработок БД. Заменяет захардкоженное тело из XbrlCsvMailProcessor.buildBody().
  Модель: uid, taskId, provId, provName, status, statusName, levelName, isError,
          flagIgnoreError, repStartDate, repEndDate, checkDate, contacts.
-->
<@c.open title="XBRL-CSV: задача ${taskId!'—'} завершена с ошибкой"/>

<p>Добрый день!</p>
<p>
    При проверке данных на уровне <strong>${levelName!"—"}</strong> по задаче
    <strong>${taskId!"не указан"}</strong> выявлены ошибки.
    <#if flagIgnoreError?? && flagIgnoreError>
        Для задачи установлен признак игнорирования ошибок — формирование пакета будет продолжено,
        но данные требуют проверки.
    <#else>
        Формирование пакета отчетности по задаче приостановлено до исправления данных.
    </#if>
</p>

<table role="presentation" cellpadding="0" cellspacing="0" border="0" width="100%"><tr><td class="<#if flagIgnoreError?? && flagIgnoreError>banner-warning<#else>banner-error</#if>">
    ${statusName!"Проверка завершена с ошибками"}
</td></tr></table>
<br/>

<@c.meta/>

<br/>
<p><strong>Что сделать:</strong> проверить и исправить данные в источнике, после чего данные будут
    повторно подготовлены и проверены автоматически при следующем запуске (каждые 15 минут).</p>

<table class="tech" role="presentation" cellpadding="0" cellspacing="0" border="0">
    <tr><td class="muted">uid уведомления:</td><td class="muted">${uid!"-"}</td></tr>
</table>

<@c.close/>
