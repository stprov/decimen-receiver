<#ftl output_format="HTML" encoding="UTF-8">
<#--
  Общие макросы писем XBRL-CSV (gmap2-vux-xbrl-csv-orchestrator).
  Стиль повторяет xbrl_protocol.ftl из gmap2-vux-ecm, но разметка табличная
  (Outlook не поддерживает flex / box-shadow / border-radius в теле письма).
  output_format="HTML" включает авто-экранирование: тексты ошибок из БД
  с символами < > & не ломают письмо.
-->

<#macro styles>
    <style type="text/css">
        body { font-family: Arial, sans-serif; font-size: 13px; color: #333333; margin: 0; padding: 0; }
        .wrap { width: 100%; background-color: #ffffff; }
        .container { width: 760px; max-width: 760px; }
        h1 { font-size: 16px; color: #2c3e50; margin: 0 0 12px 0; }
        p { margin: 0 0 10px 0; line-height: 1.45; }
        .meta td { padding: 3px 8px 3px 0; vertical-align: top; }
        .meta .label { font-weight: bold; width: 200px; color: #555555; }
        .sep { border-top: 1px solid #dddddd; height: 1px; line-height: 1px; font-size: 1px; }
        .section { font-size: 14px; font-weight: bold; color: #2c3e50; padding: 8px 10px; margin: 0; }
        .section-error { background-color: #fbe9eb; border-left: 6px solid #e57373; }
        .section-warning { background-color: #fff6da; border-left: 6px solid #f0c75e; }
        .section-info { background-color: #eef2f7; border-left: 6px solid #7f9cc0; }
        .grid { border-collapse: collapse; width: 100%; font-size: 12px; }
        .grid th { background-color: #eef2f7; text-align: left; padding: 6px 8px; border-bottom: 1px solid #bbbbbb; }
        .grid td { padding: 5px 8px; border-bottom: 1px solid #eeeeee; vertical-align: top; }
        .grid .num { text-align: right; white-space: nowrap; }
        .grid .code { font-family: 'Courier New', monospace; white-space: nowrap; }
        .zebra { background-color: #f7f7f7; }
        .banner-error { background-color: #ffebee; color: #b71c1c; padding: 10px 12px; font-size: 13px; }
        .banner-warning { background-color: #fff3cd; color: #7a5a00; padding: 10px 12px; font-size: 13px; }
        .banner-info { background-color: #e8f0fb; color: #1f4e8c; padding: 10px 12px; font-size: 13px; }
        .muted { color: #888888; font-size: 11px; }
        .tech td { font-family: 'Courier New', monospace; font-size: 11px; padding: 2px 8px 2px 0; }
        .footer { color: #777777; font-size: 11px; padding-top: 14px; border-top: 1px solid #dddddd; }
    </style>
</#macro>

<#-- Шапка письма: открывающие теги, заголовок -->
<#macro open title>
<!DOCTYPE html>
<html lang="ru">
<head>
    <meta charset="UTF-8">
    <title>${title}</title>
    <@styles/>
</head>
<body>
<table class="wrap" role="presentation" cellpadding="0" cellspacing="0" border="0"><tr><td align="center">
<table class="container" role="presentation" cellpadding="0" cellspacing="0" border="0"><tr><td style="padding: 16px;">
<h1>${title}</h1>
</#macro>

<#macro close>
<p class="footer">
    Письмо сформировано автоматически сервисом ПКАП1055 АС ГР.Отчетность ВУИКС (XBRL-CSV)
    ${checkDate!""}. Отвечать на него не нужно.
    <#if contacts?has_content><br/>По вопросам: <#list contacts as ct>${ct.name} &lt;<a href="mailto:${ct.email}">${ct.email}</a>&gt;<#sep>, </#list></#if>
</p>
</td></tr></table>
</td></tr></table>
</body>
</html>
</#macro>

<#-- Блок метаданных задачи. Поля, которых нет в модели, просто не выводятся. -->
<#macro meta>
<table class="meta" role="presentation" cellpadding="0" cellspacing="0" border="0">
    <tr><td class="label">Задача (task_id):</td><td>${taskId!"не указан"}</td></tr>
    <#if requestNumber?has_content><tr><td class="label">Номер запроса:</td><td>${requestNumber}</td></tr></#if>
    <#if sliceId?has_content><tr><td class="label">Пакет (slice_id):</td><td>${sliceId}</td></tr></#if>
    <#if provName?has_content || provId?has_content><tr><td class="label">Поставщик данных:</td><td>${provName!""}<#if provId?has_content> <span class="muted">(${provId})</span></#if></td></tr></#if>
    <tr><td class="label">Отчетный период:</td><td>${repStartDate!"—"} — ${repEndDate!"—"}</td></tr>
    <#if deadline?has_content><tr><td class="label">Срок направления в ЦБ:</td><td><strong>${deadline}</strong></td></tr></#if>
    <tr><td class="label">Уровень проверки:</td><td>${levelName!"—"}</td></tr>
    <tr><td class="label">Статус:</td><td>${statusName!"—"}<#if status??> <span class="muted">(код ${status})</span></#if></td></tr>
</table>
</#macro>

<#-- Сводка по видам проверок (аналог checksList в xbrl_protocol.ftl) -->
<#macro checksTable>
<#if checks?has_content>
<p class="section section-info">Результат проверки</p>
<table class="grid" cellpadding="0" cellspacing="0" border="0">
    <thead><tr><th>Код</th><th>Вид проверки</th><th class="num">Отклонений</th></tr></thead>
    <tbody>
    <#list checks as ch>
        <tr<#if ch?is_odd_item> class="zebra"</#if>>
            <td class="code">${ch.code!"-"}</td>
            <td>${ch.name!"-"}</td>
            <td class="num"<#if (ch.count!0) gt 0> style="color:#c62828;font-weight:bold;"</#if>>${ch.count!0}</td>
        </tr>
    </#list>
    </tbody>
</table>
</#if>
</#macro>

<#-- Таблица ошибок. showProvider / showSlice добавляют колонки. -->
<#macro errorsTable title cssClass="section-error" showProvider=false showSlice=false>
<#if errors?has_content>
<p class="section ${cssClass}">${title}</p>
<table class="grid" cellpadding="0" cellspacing="0" border="0">
    <thead><tr>
        <th>№</th>
        <#if showSlice><th>slice_id</th></#if>
        <#if showProvider><th>Поставщик</th></#if>
        <th>Раздел</th>
        <th>Объект (ключ строки)</th>
        <th>Поле</th>
        <th>Код ошибки</th>
        <th>Описание ошибки</th>
    </tr></thead>
    <tbody>
    <#list errors as e>
        <tr<#if e?is_odd_item> class="zebra"</#if>>
            <td>${e?counter}</td>
            <#if showSlice><td class="code">${e.sliceId!"-"}</td></#if>
            <#if showProvider><td>${e.provName!"-"}</td></#if>
            <td>${e.chapter!"-"}</td>
            <td>${e.objectKey!"-"}</td>
            <td class="code">${e.column!"-"}</td>
            <td class="code">${e.errorCode!"-"}</td>
            <td>${e.errorMessage!"-"}</td>
        </tr>
    </#list>
    </tbody>
</table>
<#if (totalErrorCount!0) gt errors?size>
<p class="muted">Показано ${errors?size} из ${totalErrorCount}. Полный перечень ошибок — в витрине ошибок по task_id ${taskId!""}.</p>
</#if>
</#if>
</#macro>
