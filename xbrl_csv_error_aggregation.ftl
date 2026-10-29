<#ftl output_format="HTML" encoding="UTF-8">
<#import "xbrl_csv_mail_common.ftl" as c>
<#--
  Вариант 3. Сводка для ВСЕХ поставщиков задачи — status = 4
  («проверен с ошибками в слое агрегации»: после консолидации и дедупликации).
  Ошибка агрегации может касаться пересечения данных разных поставщиков,
  поэтому письмо одно на задачу и показывает разбивку по поставщикам.
  Дополнительно к модели варианта 2: providers[] { provName, provId, errorCount }.
-->
<@c.open title="XBRL-CSV: ошибки агрегации по задаче ${taskId!'—'}"/>

<p>Добрый день, коллеги!</p>
<p>
    После объединения данных всех поставщиков по задаче <strong>${taskId!"—"}</strong>
    (период ${repStartDate!"—"} — ${repEndDate!"—"}) проверка в слое агрегации выявила ошибки.
    Формирование пакета отчетности остановлено. Письмо направлено всем поставщикам задачи:
    ошибка одного поставщика может блокировать отчет целиком.
</p>

<@c.meta/>
<br/>

<#if providers?has_content>
<p class="section section-warning">Ошибки в разрезе поставщиков</p>
<table class="grid" cellpadding="0" cellspacing="0" border="0">
    <thead><tr><th>Поставщик</th><th>Код поставщика</th><th class="num">Ошибок</th></tr></thead>
    <tbody>
    <#list providers as p>
        <tr<#if p?is_odd_item> class="zebra"</#if>>
            <td>${p.provName!"-"}</td>
            <td class="code">${p.provId!"-"}</td>
            <td class="num"<#if (p.errorCount!0) gt 0> style="color:#c62828;font-weight:bold;"</#if>>${p.errorCount!0}</td>
        </tr>
    </#list>
    </tbody>
</table>
<br/>
</#if>

<@c.checksTable/>
<br/>
<@c.errorsTable title="Список ошибок" showProvider=true/>

<@c.close/>
