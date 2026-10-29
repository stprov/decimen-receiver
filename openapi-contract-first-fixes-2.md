# Исправления №2 к задаче «contract-first OpenAPI»

## Что это

Применяется **после** `openapi-contract-first-task.md` и `openapi-contract-first-fixes.md`. Цель — чтобы поведение эндпоинта совпадало с исходной версией проекта на 100%, включая краевые случаи.

Версия генератора остаётся **7.26.0**. Все правки ниже проверены на 7.26.0.

## Какие расхождения закрываются

| # | Случай | Исходный проект | После первых двух md | После этого файла |
|---|---|---|---|---|
| 1 | `documentType` = `""` или `"   "` | 400, `Request validation failed` | 400, `Unknown documentType: ''` | 400, `Request validation failed` |
| 2 | Строка только из управляющих символов (`"\u0001"`) в `s3Path`/`filename`/`sliceId` | 400, `Request validation failed` | проходила валидацию | 400, `Request validation failed` |
| 3 | `Content-Type`/`Accept` вида `application/*+json` (например `application/vnd.x+json`) | принимается | отклонялся (генератор добавил `consumes`/`produces`) | принимается |
| 4 | Контроллер — AOP-прокси из-за `@Validated` на сгенерированном интерфейсе | обычный бин | прокси | обычный бин |

Как закрываются:
- 1 и 2: на все 4 поля сгенерированного DTO добавляется `@NotBlank` (как в исходном record) через расширение `x-field-extra-annotation` в yaml. Генератор ставит его на поле, `@NotNull @Pattern` остаются на геттере. Множество отклоняемых значений получается ровно как у `@NotBlank`.
- 3: в контроллере на методе явно объявляется `@PostMapping(UploadApi.PATH_UPLOAD_BY_S3_PATH)` без `consumes`/`produces`. Spring берёт маппинг с метода класса, а не с интерфейса, поэтому принимаемые и отдаваемые типы — как в исходном `@PostMapping("/by-s3-path")`. Путь берётся из константы сгенерированного интерфейса, то есть остаётся привязанным к контракту.
- 4: опция генератора `useSpringBuiltInValidation=true` убирает `@Validated` с интерфейса. Валидация тела запроса через `@Valid @RequestBody` работает как раньше (`MethodArgumentNotValidException` → 400).

---

## Правка 1. `openapi.yaml` (корень проекта)

Добавить 4 строки `x-field-extra-annotation`. Итоговое содержимое файла целиком:

```yaml
openapi: 3.0.3
info:
  title: gmap2-vux-ecm API
  version: 1.0.0
tags:
  - name: Upload
    description: Загрузка документов в ECM
paths:
  /api/v1/upload/by-s3-path:
    post:
      tags: [Upload]
      operationId: uploadByS3Path
      summary: Загрузка документа в ECM по пути в S3
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/UploadByS3PathRequest'
      responses:
        '200':
          description: Документ принят, возвращается rqUid запроса в ECM
          content:
            application/json:
              schema:
                type: string
                format: uuid
        '400':
          description: Некорректный запрос
          content:
            application/problem+json:
              schema:
                $ref: '#/components/schemas/ProblemDetail'
        '500':
          description: Внутренняя ошибка или ошибка ECM
          content:
            application/problem+json:
              schema:
                $ref: '#/components/schemas/ProblemDetail'
components:
  schemas:
    UploadByS3PathRequest:
      type: object
      required: [s3Path, filename, documentType, sliceId]
      properties:
        s3Path:
          type: string
          x-field-extra-annotation: "@jakarta.validation.constraints.NotBlank"
          pattern: '[\s\S]*\S[\s\S]*'
          example: folder/file.pdf
        filename:
          type: string
          x-field-extra-annotation: "@jakarta.validation.constraints.NotBlank"
          pattern: '[\s\S]*\S[\s\S]*'
          example: file.pdf
        documentType:
          $ref: '#/components/schemas/DocumentType'
        sliceId:
          type: string
          x-field-extra-annotation: "@jakarta.validation.constraints.NotBlank"
          pattern: '[\s\S]*\S[\s\S]*'
          example: slice-1
    DocumentType:
      type: string
      x-field-extra-annotation: "@jakarta.validation.constraints.NotBlank"
      description: Имя константы ru.sbrf.gmap.vux.model.DocumentTypeEnum
      enum:
        - XBRL_VUX_RFVP_DOCUMENT
        - XBRL_VUX_RPVP_DOCUMENT
        - XBRL_DOCUMENT
        - XBRL_CSV_RPVP_DOCUMENT
        - XBRL_CSV_RP_DOCUMENT
    ProblemDetail:
      type: object
      properties:
        type:
          type: string
        title:
          type: string
        status:
          type: integer
        detail:
          type: string
        instance:
          type: string
```

Важно: у `DocumentType` расширение ставится **на саму схему** `DocumentType` (не рядом с `$ref` в свойстве — в OpenAPI 3.0 соседние с `$ref` ключи игнорируются).

`pattern` и `enum` остаются: они нужны Schemathesis, чтобы генерировать валидные значения.

---

## Правка 2. Корневой `pom.xml`, плагин `openapi-generator-maven-plugin`

В `<configOptions>` добавить одну строку:

```xml
<useSpringBuiltInValidation>true</useSpringBuiltInValidation>
```

Итоговый `<configOptions>`:

```xml
<configOptions>
    <interfaceOnly>true</interfaceOnly>
    <skipDefaultInterface>true</skipDefaultInterface>
    <useSpringBoot4>true</useSpringBoot4>
    <useBeanValidation>true</useBeanValidation>
    <useSpringBuiltInValidation>true</useSpringBuiltInValidation>
    <useTags>true</useTags>
    <openApiNullable>false</openApiNullable>
    <documentationProvider>none</documentationProvider>
    <annotationLibrary>none</annotationLibrary>
</configOptions>
```

Остальное в конфигурации плагина (версия 7.26.0, `schemaMappings`, пакеты, отключённые тесты и документация) — без изменений.

### Проверка после правок 1–2

`mvn -pl service -am clean generate-sources`, затем убедиться:
- в `service/target/generated-sources/openapi/src/main/java/ru/sbrf/gmap/vux/api/model/UploadByS3PathRequestDto.java` над **всеми четырьмя** полями (`s3Path`, `filename`, `documentType`, `sliceId`) стоит `@jakarta.validation.constraints.NotBlank`;
- в `service/target/generated-sources/openapi/src/main/java/ru/sbrf/gmap/vux/api/UploadApi.java` **нет** `@Validated`;
- в `UploadApi` метод по-прежнему `ResponseEntity<UUID> uploadByS3Path(@Valid @RequestBody UploadByS3PathRequestDto uploadByS3PathRequestDto)`;
- `DocumentTypeDto.java` по-прежнему нет.

---

## Правка 3. `UploadController` — явный `@PostMapping` без consumes/produces

Файл `service/src/main/java/ru/sbrf/gmap/vux/controller/UploadController.java` полностью заменить на:

```java
package ru.sbrf.gmap.vux.controller;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RestController;
import ru.sbrf.gmap.vux.api.UploadApi;
import ru.sbrf.gmap.vux.api.model.UploadByS3PathRequestDto;
import ru.sbrf.gmap.vux.model.DocumentTypeEnum;
import ru.sbrf.gmap.vux.service.UploadDocumentService;

import java.util.UUID;

@Slf4j
@RestController
@RequiredArgsConstructor
public class UploadController implements UploadApi {

    private final UploadDocumentService uploadDocumentService;

    /**
     * Загрузка документа в ECM по ссылке на объект в S3.
     * Контракт эндпоинта описан в openapi.yaml в корне проекта.
     * <p>
     * Маппинг объявлен явно без consumes/produces, чтобы принимаемые и отдаваемые
     * типы контента совпадали с исходной реализацией (application/json и application/*+json).
     *
     * @param request параметры загрузки
     * @return сформированный {@code rqUid} запроса в ЕСМ
     */
    @Override
    @PostMapping(UploadApi.PATH_UPLOAD_BY_S3_PATH)
    public ResponseEntity<UUID> uploadByS3Path(UploadByS3PathRequestDto request) {
        DocumentTypeEnum documentType = resolveDocumentType(request.getDocumentType());
        UUID rqUid = uploadDocumentService.uploadDocumentViaTfsByS3Path(
                request.getS3Path(),
                request.getFilename(),
                documentType,
                request.getSliceId()
        );
        log.info("Document by S3 path '{}' accepted for upload, rqUid: '{}'", request.getS3Path(), rqUid);
        return ResponseEntity.ok(rqUid);
    }

    private DocumentTypeEnum resolveDocumentType(String value) {
        try {
            return DocumentTypeEnum.valueOf(value);
        } catch (IllegalArgumentException | NullPointerException e) {
            throw new IllegalArgumentException("Unknown documentType: '" + value + "'", e);
        }
    }
}
```

Отличие от предыдущей версии — только аннотация `@PostMapping(UploadApi.PATH_UPLOAD_BY_S3_PATH)` на методе (и её импорт).

Обязательно:
- `@Valid` и `@RequestBody` на параметре **не** добавлять: Spring берёт их из интерфейса.
- На классе по-прежнему **нет** `@RequestMapping`.
- В `@PostMapping` **не** добавлять `consumes`/`produces`.

---

## Правка 4. `UploadControllerWebTest` — тесты на закрытые расхождения

В файл `service/src/test/java/ru/sbrf/gmap/vux/controller/UploadControllerWebTest.java` **добавить** 3 теста (существующие 4 теста не трогать):

```java
    @Test
    @DisplayName("пустой documentType: 400 Request validation failed (как в исходной версии)")
    void blankDocumentType_returns400ValidationFailed() throws Exception {
        mockMvc.perform(post(URL)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"s3Path":"folder/file.pdf","filename":"file.pdf","documentType":"  ","sliceId":"slice-1"}
                                """))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.detail").value("Request validation failed"));
        verifyNoInteractions(uploadDocumentService);
    }

    @Test
    @DisplayName("s3Path только из управляющего символа: 400 Request validation failed")
    void controlCharS3Path_returns400ValidationFailed() throws Exception {
        mockMvc.perform(post(URL)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"s3Path":"\\u0001","filename":"file.pdf","documentType":"XBRL_DOCUMENT","sliceId":"slice-1"}
                                """))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.detail").value("Request validation failed"));
        verifyNoInteractions(uploadDocumentService);
    }

    @Test
    @DisplayName("Content-Type application/*+json принимается (как в исходной версии)")
    void vendorJsonContentType_returns200() throws Exception {
        UUID rqUid = UUID.fromString("123e4567-e89b-12d3-a456-426614174000");
        when(uploadDocumentService.uploadDocumentViaTfsByS3Path(
                "folder/file.pdf", "file.pdf", DocumentTypeEnum.XBRL_DOCUMENT, "slice-1"))
                .thenReturn(rqUid);

        mockMvc.perform(post(URL)
                        .contentType("application/vnd.test+json")
                        .content("""
                                {"s3Path":"folder/file.pdf","filename":"file.pdf","documentType":"XBRL_DOCUMENT","sliceId":"slice-1"}
                                """))
                .andExpect(status().isOk())
                .andExpect(content().string(containsString(rqUid.toString())));
    }
```

Примечания:
- В тесте с управляющим символом в Java-коде написано именно `\\u0001` (два обратных слэша). Так в JSON попадает escape-последовательность `\u0001`, и Jackson превращает её в символ U+0001. С одним слэшем Java подставит сырой символ ещё при компиляции, JSON станет невалидным, и тест проверит не то.
- Все нужные импорты (`MediaType`, `UUID`, `DocumentTypeEnum`, `containsString`, `jsonPath`, `content`, `status`, `post`, `when`, `verifyNoInteractions`) в файле уже есть.

---

## Финальная проверка

1. `mvn clean verify` из корня проекта — сборка и все тесты проходят (в `UploadControllerWebTest` 7 тестов, в `UploadControllerTest` 2 теста).
2. В сгенерированном `UploadByS3PathRequestDto` — `@NotBlank` на 4 полях; в `UploadApi` — нет `@Validated`.
3. В `UploadController`: нет `@RequestMapping` на классе, на методе `@PostMapping(UploadApi.PATH_UPLOAD_BY_S3_PATH)` без consumes/produces, есть `resolveDocumentType`.
4. Поиск по проекту `DocumentTypeDto` и `ru.sbrf.gmap.vux.dto.request.ecm.UploadByS3PathRequestDto` — 0 совпадений.

## Итоговое поведение = исходное

| Запрос | Ответ |
|---|---|
| Валидное тело, `Content-Type: application/json` или `application/*+json` | 200, тело `"<uuid>"` |
| `documentType` не из списка | 400, `application/problem+json`, detail `Unknown documentType: '...'` |
| Пустое, пробельное или из управляющих символов любое из 4 полей (включая `documentType`) | 400, detail `Request validation failed` |
| Нет обязательного поля | 400, detail `Request validation failed` |
| Битый JSON / пустое тело | 400, detail `Malformed request body` |
| Ошибка ECM/S3 | 500, `application/problem+json` |

## Что осталось отличаться от исходного проекта (не влияет на поведение API)

- Сборка использует плагин `openapi-generator-maven-plugin:7.26.0` — он должен быть доступен в Nexus/Jenkins.
- В сгенерированном коде есть deprecation-warning'и на `org.springframework.lang.Nullable` (в Spring 7 аннотация помечена deprecated). Сборку не ломают.
- Генерируется неиспользуемый `ProblemDetailDto` — безвреден.
- DTO запроса теперь генерируемый класс в пакете `ru.sbrf.gmap.vux.api.model`, а не record в `ru.sbrf.gmap.vux.dto.request.ecm` — внутренняя деталь, снаружи не видна.
