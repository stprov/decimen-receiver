<#ftl output_format="HTML" encoding="UTF-8">
<#import "xbrl_csv_mail_common.ftl" as c>
<#--
  Вариант 4. Технический отчет для КОМАНДЫ ВУИКС — status = 6
  («проверен с ошибками в слое нарезки»: разметка отчета на пакеты t_vux_xbrl_csv_slice,
  заполнение t_vux_form_xbrl_csv_add_info, проверка пакетов).
  Поставщику такие ошибки не исправить, поэтому письмо внутреннее и содержит
  технические идентификаторы для разбора.
  Дополнительно к модели варианта 2: slices[] { sliceId, sliceNum, version, startDate, endDate, errorCount }.
-->
<@c.open title="[ВУИКС] XBRL-CSV: ошибки нарезки пакетов, задача ${taskId!'—'}"/>

<p>Коллеги, при разметке отчета на пакеты по задаче <strong>${taskId!"—"}</strong>
    найдены ошибки. Пакеты с ошибками не будут выложены в ЕСМ и задачи в СУПЗ по ним не будут созданы.</p>

<@c.meta/>
<br/>

<#if slices?has_content>
<p class="section section-error">Пакеты с ошибками</p>
<table class="grid" cellpadding="0" cellspacing="0" border="0">
    <thead><tr><th>slice_id</th><th>№ / версия</th><th>Период пакета</th><th class="num">Ошибок</th></tr></thead>
    <tbody>
    <#list slices as s>
        <tr<#if s?is_odd_item> class="zebra"</#if>>
            <td class="code">${s.sliceId!"-"}</td>
            <td>${s.sliceNum!"-"} / v${s.version!"-"}</td>
            <td>${s.startDate!"—"} — ${s.endDate!"—"}</td>
            <td class="num" style="color:#c62828;font-weight:bold;">${s.errorCount!0}</td>
        </tr>
    </#list>
    </tbody>
</table>
<br/>
</#if>

<@c.checksTable/>
<br/>
<@c.errorsTable title="Детализация ошибок" showSlice=true/>

<p class="section section-info">Технические данные</p>
<table class="tech" role="presentation" cellpadding="0" cellspacing="0" border="0">
    <tr><td>uid уведомления</td><td>${uid!"-"}</td></tr>
    <tr><td>task_id</td><td>${taskId!"-"}</td></tr>
    <#if srcTaskId?has_content><tr><td>src_task_id</td><td>${srcTaskId}</td></tr></#if>
    <tr><td>status / is_error</td><td>${status!"-"} / ${isError!"-"}</td></tr>
    <tr><td>flag_ignore_error</td><td><#if flagIgnoreError??>${flagIgnoreError?string("1", "0")}<#else>-</#if></td></tr>
</table>

<@c.close/>
