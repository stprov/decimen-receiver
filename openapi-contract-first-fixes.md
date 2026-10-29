# Исправления к задаче «contract-first OpenAPI» (дополнение к openapi-contract-first-task.md)

## Что это

Первая версия задачи (`openapi-contract-first-task.md`) уже выполнена или выполняется. Этот файл содержит **только исправления** к ней. Применить их поверх сделанного.

## Зачем исправления

1. **Внешнее поведение эндпоинта не должно меняться.** В первой версии `documentType` стал enum-ом, и при неверном значении ответ менялся с `Unknown documentType: 'X'` на `Malformed request body`. Теперь `documentType` генерируется как `String`, остаётся прежний `resolveDocumentType`, и текст ошибки сохраняется.
2. **Генератор под Spring Boot 4.** В 7.18.0 есть только режим `useSpringBoot3`. Опция `useSpringBoot4` появилась в **7.20.0**. Конфигурация ниже проверена на **7.26.0**.
3. **Нет дублирования enum в Java.** Класс `DocumentTypeDto` больше не генерируется. В Java остаётся только существующий `ru.sbrf.gmap.vux.model.DocumentTypeEnum`, список значений есть только в `openapi.yaml` как контракт.

## Что НЕ меняется

- `openapi.yaml` в корне проекта — без изменений.
- `service/pom.xml` — без изменений (там только ссылка на плагин).
- Удаление старого `ru.sbrf.gmap.vux.dto.request.ecm.UploadByS3PathRequestDto` — остаётся в силе.
- Удаление `@RequestMapping` с класса `UploadController` — остаётся в силе.
- `UploadDocumentService`, `DocumentTypeEnum`, `GlobalExceptionHandler`, `build-helper-maven-plugin` — не трогать.
- Новые зависимости не добавлять.

---

## Исправление 1. Версия генератора (корневой `pom.xml`, `<properties>`)

Было:

```xml
<openapi-generator.version>7.18.0</openapi-generator.version>
```

Стало:

```xml
<openapi-generator.version>7.26.0</openapi-generator.version>
```

Если 7.26.0 нет в корпоративном Nexus, взять самую свежую доступную версию **не ниже 7.20.0**.

## Исправление 2. Конфигурация плагина (корневой `pom.xml`, `<pluginManagement>`)

В блоке `<configuration>` плагина `openapi-generator-maven-plugin`:

**2.1.** Добавить строку (на уровне `<configuration>`, рядом с `<modelNameSuffix>`):

```xml
<schemaMappings>DocumentType=java.lang.String</schemaMappings>
```

**2.2.** В `<configOptions>` **удалить** две строки:

```xml
<useSpringBoot3>true</useSpringBoot3>
<useJakartaEe>true</useJakartaEe>
```

и **добавить** вместо них:

```xml
<useSpringBoot4>true</useSpringBoot4>
```

(`useSpringBoot4` сам включает jakarta-импорты.)

Итоговый блок `<configuration>` должен выглядеть так:

```xml
<configuration>
    <inputSpec>${project.basedir}/../openapi.yaml</inputSpec>
    <generatorName>spring</generatorName>
    <output>${project.build.directory}/generated-sources/openapi</output>
    <apiPackage>ru.sbrf.gmap.vux.api</apiPackage>
    <modelPackage>ru.sbrf.gmap.vux.api.model</modelPackage>
    <modelNameSuffix>Dto</modelNameSuffix>
    <schemaMappings>DocumentType=java.lang.String</schemaMappings>
    <generateApiTests>false</generateApiTests>
    <generateModelTests>false</generateModelTests>
    <generateApiDocumentation>false</generateApiDocumentation>
    <generateModelDocumentation>false</generateModelDocumentation>
    <generateSupportingFiles>false</generateSupportingFiles>
    <configOptions>
        <interfaceOnly>true</interfaceOnly>
        <skipDefaultInterface>true</skipDefaultInterface>
        <useSpringBoot4>true</useSpringBoot4>
        <useBeanValidation>true</useBeanValidation>
        <useTags>true</useTags>
        <openApiNullable>false</openApiNullable>
        <documentationProvider>none</documentationProvider>
        <annotationLibrary>none</annotationLibrary>
    </configOptions>
</configuration>
```

### Проверка после исправлений 1–2

Выполнить `mvn -pl service -am clean generate-sources` и убедиться:
- в `service/target/generated-sources/openapi/src/main/java/ru/sbrf/gmap/vux/api/model/` есть `UploadByS3PathRequestDto.java` и `ProblemDetailDto.java`, а **`DocumentTypeDto.java` нет**;
- в `UploadByS3PathRequestDto` поле, геттер и fluent-сеттер `documentType` имеют тип `java.lang.String`;
- `UploadApi` не изменился: `ResponseEntity<UUID> uploadByS3Path(@Valid @RequestBody UploadByS3PathRequestDto uploadByS3PathRequestDto)`.

Важно: обязательно `clean`, иначе в `target` останется старый `DocumentTypeDto.java` от предыдущей генерации.

---

## Исправление 3. `UploadController` — вернуть `resolveDocumentType`

Файл `service/src/main/java/ru/sbrf/gmap/vux/controller/UploadController.java` полностью заменить на:

```java
package ru.sbrf.gmap.vux.controller;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
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
     *
     * @param request параметры загрузки
     * @return сформированный {@code rqUid} запроса в ЕСМ
     */
    @Override
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

Отличие от первой версии: вместо `DocumentTypeEnum.valueOf(request.getDocumentType().name())` используется прежний `resolveDocumentType(String)`. Импорта `DocumentTypeDto` быть не должно. На классе по-прежнему **нет** `@RequestMapping`.

---

## Исправление 4. `UploadControllerTest` — вернуть тест на неверный тип

Файл `service/src/test/java/ru/sbrf/gmap/vux/controller/UploadControllerTest.java` полностью заменить на:

```java
package ru.sbrf.gmap.vux.controller;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import ru.sbrf.gmap.vux.api.model.UploadByS3PathRequestDto;
import ru.sbrf.gmap.vux.model.DocumentTypeEnum;
import ru.sbrf.gmap.vux.service.UploadDocumentService;

import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
@DisplayName("UploadController")
class UploadControllerTest {

    @Mock
    private UploadDocumentService uploadDocumentService;

    @InjectMocks
    private UploadController uploadController;

    @Test
    @DisplayName("успешный вызов возвращает rqUid")
    void uploadByS3Path_success_returnsRqUid() {
        UUID rqUid = UUID.fromString("123e4567-e89b-12d3-a456-426614174000");
        when(uploadDocumentService.uploadDocumentViaTfsByS3Path(
                "folder/file.pdf", "file.pdf", DocumentTypeEnum.XBRL_DOCUMENT, "slice-1"))
                .thenReturn(rqUid);

        UploadByS3PathRequestDto request = new UploadByS3PathRequestDto()
                .s3Path("folder/file.pdf")
                .filename("file.pdf")
                .documentType("XBRL_DOCUMENT")
                .sliceId("slice-1");

        ResponseEntity<UUID> response = uploadController.uploadByS3Path(request);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(response.getBody()).isEqualTo(rqUid);
    }

    @Test
    @DisplayName("некорректный documentType бросает IllegalArgumentException")
    void uploadByS3Path_invalidDocumentType_throws() {
        UploadByS3PathRequestDto request = new UploadByS3PathRequestDto()
                .s3Path("folder/file.pdf")
                .filename("file.pdf")
                .documentType("UNKNOWN_TYPE")
                .sliceId("slice-1");

        assertThatThrownBy(() -> uploadController.uploadByS3Path(request))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("UNKNOWN_TYPE");
    }
}
```

Отличия от первой версии:
- `documentType` передаётся строкой (`"XBRL_DOCUMENT"`), а не `DocumentTypeDto.XBRL_DOCUMENT`;
- тест `documentTypeDto_allValuesMapToDomainEnum` **удалён** (класса `DocumentTypeDto` больше нет);
- возвращён тест `uploadByS3Path_invalidDocumentType_throws` (как в исходной версии проекта).

---

## Исправление 5. `UploadControllerWebTest` — проверять прежние тексты ошибок

Файл `service/src/test/java/ru/sbrf/gmap/vux/controller/UploadControllerWebTest.java` полностью заменить на:

```java
package ru.sbrf.gmap.vux.controller;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import ru.sbrf.gmap.vux.exception.handler.GlobalExceptionHandler;
import ru.sbrf.gmap.vux.model.DocumentTypeEnum;
import ru.sbrf.gmap.vux.service.UploadDocumentService;

import java.util.UUID;

import static org.hamcrest.Matchers.containsString;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@ExtendWith(MockitoExtension.class)
@DisplayName("UploadController (HTTP)")
class UploadControllerWebTest {

    private static final String URL = "/api/v1/upload/by-s3-path";

    @Mock
    private UploadDocumentService uploadDocumentService;

    private MockMvc mockMvc;

    @BeforeEach
    void setUp() {
        mockMvc = MockMvcBuilders
                .standaloneSetup(new UploadController(uploadDocumentService))
                .setControllerAdvice(new GlobalExceptionHandler())
                .build();
    }

    @Test
    @DisplayName("валидный запрос: 200 и rqUid в теле")
    void validRequest_returns200() throws Exception {
        UUID rqUid = UUID.fromString("123e4567-e89b-12d3-a456-426614174000");
        when(uploadDocumentService.uploadDocumentViaTfsByS3Path(
                "folder/file.pdf", "file.pdf", DocumentTypeEnum.XBRL_DOCUMENT, "slice-1"))
                .thenReturn(rqUid);

        mockMvc.perform(post(URL)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"s3Path":"folder/file.pdf","filename":"file.pdf","documentType":"XBRL_DOCUMENT","sliceId":"slice-1"}
                                """))
                .andExpect(status().isOk())
                .andExpect(content().string(containsString(rqUid.toString())));
    }

    @Test
    @DisplayName("неизвестный documentType: 400 с прежним текстом ошибки")
    void unknownDocumentType_returns400WithSameMessage() throws Exception {
        mockMvc.perform(post(URL)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"s3Path":"folder/file.pdf","filename":"file.pdf","documentType":"WRONG","sliceId":"slice-1"}
                                """))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.detail").value("Unknown documentType: 'WRONG'"));
        verifyNoInteractions(uploadDocumentService);
    }

    @Test
    @DisplayName("s3Path из пробелов: 400")
    void blankS3Path_returns400() throws Exception {
        mockMvc.perform(post(URL)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"s3Path":"   ","filename":"file.pdf","documentType":"XBRL_DOCUMENT","sliceId":"slice-1"}
                                """))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.detail").value("Request validation failed"));
        verifyNoInteractions(uploadDocumentService);
    }

    @Test
    @DisplayName("отсутствует обязательное поле sliceId: 400")
    void missingSliceId_returns400() throws Exception {
        mockMvc.perform(post(URL)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"s3Path":"folder/file.pdf","filename":"file.pdf","documentType":"XBRL_DOCUMENT"}
                                """))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.detail").value("Request validation failed"));
        verifyNoInteractions(uploadDocumentService);
    }
}
```

Отличия от первой версии:
- неверный `documentType` теперь проверяется на **прежний** текст `Unknown documentType: 'WRONG'`;
- для пробельного и отсутствующего поля дополнительно проверяется текст `Request validation failed`;
- проверка тела успешного ответа сделана через `containsString`, чтобы не зависеть от кавычек вокруг UUID.

`spring-test` (MockMvc), `json-path` и `hamcrest` приходят из уже подключённого `spring-boot-starter-test` — новых зависимостей не добавлять.

---

## Финальная проверка

1. Поиск по проекту `DocumentTypeDto` (в `src/main` и `src/test`) — **0 совпадений**.
2. Поиск `ru.sbrf.gmap.vux.dto.request.ecm.UploadByS3PathRequestDto` — **0 совпадений**.
3. На классе `UploadController` нет `@RequestMapping`.
4. В корневом `pom.xml` нет `useSpringBoot3` и `useJakartaEe` в конфигурации openapi-плагина, есть `useSpringBoot4` и `schemaMappings`.
5. `mvn clean verify` из корня проекта — сборка и все тесты проходят.
6. Предупреждения про устаревший `org.springframework.lang.Nullable` в сгенерированном коде допустимы, это не ошибка.

## Ожидаемое поведение (должно совпадать с тем, что было до перехода)

| Запрос | Ответ |
|---|---|
| Валидное тело | 200, `application/json`, тело `"<uuid>"` |
| `documentType` не из списка | 400, `application/problem+json`, detail `Unknown documentType: '...'` |
| Пустая или пробельная строка в `s3Path`/`filename`/`sliceId` | 400, detail `Request validation failed` |
| Нет обязательного поля | 400, detail `Request validation failed` |
| Ошибка ECM/S3 | 500, `application/problem+json` |
