<#ftl output_format="HTML" encoding="UTF-8">
<#import "xbrl_csv_mail_common.ftl" as c>
<#--
  Вариант 2. Протокол для ПОСТАВЩИКА — status = 2
  («проверен с ошибками в интеграционном слое»). Получают только поставщики,
  у которых найдены ошибки (по prov_id).
  Структура повторяет xbrl_protocol.ftl (gmap2-vux-ecm): метаданные → результат по видам
  проверок → список ошибок с лимитом «показано N из M».
  Требует доработки БД: errors / checks / totalErrorCount (см. аналитику, раздел «Вопросы»).
-->
<@c.open title="Протокол проверки данных XBRL-CSV — ${provName!'поставщик'}"/>

<p>Добрый день!</p>
<p>
    В данных, переданных для задачи <strong>${taskId!"—"}</strong>
    за период <strong>${repStartDate!"—"} — ${repEndDate!"—"}</strong>,
    при проверке в интеграционном слое найдены ошибки. Просим исправить данные
    и повторно направить их на подготовку.
</p>

<@c.meta/>
<br/>

<#if (totalErrorCount!0) gt 0>
<table role="presentation" cellpadding="0" cellspacing="0" border="0" width="100%"><tr><td class="banner-error">
    Найдено ошибок: <strong>${totalErrorCount}</strong><#if errors?has_content && totalErrorCount gt errors?size> (в письме показаны первые ${errors?size})</#if>
</td></tr></table>
<br/>
</#if>

<@c.checksTable/>
<br/>
<@c.errorsTable title="Список ошибок"/>

<@c.close/>
