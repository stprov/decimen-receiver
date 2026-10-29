# Задача: перевести REST API сервиса gmap2-vux-ecm на contract-first (OpenAPI)

## Контекст

- Проект: `gmap2-vux-ecm`, Spring Boot **4.0.7**, Java 21, Maven. Модули: корневой `pom.xml` (packaging pom) и `service`.
- В сервисе один REST-эндпоинт: `POST /api/v1/upload/by-s3-path` в `service/src/main/java/ru/sbrf/gmap/vux/controller/UploadController.java`.
- Цель: файл `openapi.yaml` в **корне проекта** становится источником правды. Из него при каждой сборке генерируются интерфейс контроллера и DTO. Контроллер реализует сгенерированный интерфейс. Этот же файл используется для контрактного тестирования (Schemathesis) на стенде FAT.

## Что уже проверено (не перепроверять, не спорить)

- Конфигурация генератора ниже проверена на openapi-generator **7.18.0**. Он создаёт:
  - `ru.sbrf.gmap.vux.api.UploadApi` — интерфейс с методом
    `ResponseEntity<UUID> uploadByS3Path(@Valid @RequestBody UploadByS3PathRequestDto uploadByS3PathRequestDto)`
    и полным путём `/api/v1/upload/by-s3-path` (константа `UploadApi.PATH_UPLOAD_BY_S3_PATH`);
  - `ru.sbrf.gmap.vux.api.model.UploadByS3PathRequestDto` — POJO с геттерами (`getS3Path()`, `getFilename()`, `getDocumentType()`, `getSliceId()`), fluent-сеттерами (`.s3Path(...)`), конструктором без аргументов и конструктором со всеми 4 полями;
  - `ru.sbrf.gmap.vux.api.model.DocumentTypeDto` — enum с **теми же именами констант**, что `ru.sbrf.gmap.vux.model.DocumentTypeEnum`;
  - `ru.sbrf.gmap.vux.api.model.ProblemDetailDto` — не используется, это нормально.
- Сгенерированный код **не** импортирует `io.swagger.*` и **не** требует `jackson-databind-nullable`: это отключено опциями `annotationLibrary=none`, `documentationProvider=none`, `openApiNullable=false`. **Новые зависимости в pom не добавлять.**
- Нужные для сгенерированного кода библиотеки (`com.fasterxml.jackson.annotation`, `jakarta.validation`, `jakarta.annotation`) уже есть через `spring-boot-starter-web` и `spring-boot-starter-validation`.
- Тесты и документацию генератор не создаёт (отключено).
- openapi-плагин сам добавляет `target/generated-sources/openapi` в исходники. **`build-helper-maven-plugin` не трогать**, он используется для JAXB и к этой задаче не относится.
- Старый `ru.sbrf.gmap.vux.dto.request.ecm.UploadByS3PathRequestDto` используется только в `UploadController` и `UploadControllerTest`.

## Чего НЕ делать

- Не добавлять Lombok-аннотации (`additionalModelTypeAnnotations`) к сгенерированным моделям: генератор сам создаёт конструктор со всеми полями, `@AllArgsConstructor` даст ошибку компиляции.
- Не добавлять зависимости springdoc, swagger-annotations, jackson-databind-nullable.
- Не менять `UploadDocumentService`, `DocumentTypeEnum`, `GlobalExceptionHandler`, `build-helper-maven-plugin`, JAXB-конфигурацию.
- Не редактировать файлы в `target/generated-sources` вручную.

---

## Шаг 1. Создать `openapi.yaml` в корне проекта

Путь: `gmap2-vux-ecm/openapi.yaml` (рядом с корневым `pom.xml`, НЕ внутри `service`). Содержимое строго такое:

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
          pattern: '[\s\S]*\S[\s\S]*'
          example: folder/file.pdf
        filename:
          type: string
          pattern: '[\s\S]*\S[\s\S]*'
          example: file.pdf
        documentType:
          $ref: '#/components/schemas/DocumentType'
        sliceId:
          type: string
          pattern: '[\s\S]*\S[\s\S]*'
          example: slice-1
    DocumentType:
      type: string
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

Пояснения:
- `pattern: '[\s\S]*\S[\s\S]*'` = «есть хотя бы один непробельный символ», точный аналог `@NotBlank`. Генератор превращает его в `@NotNull @Pattern(...)`.
- Значения `enum` должны совпадать с именами констант `DocumentTypeEnum`. При добавлении нового типа документа в Java его нужно добавить и сюда.

---

## Шаг 2. Подключить генератор в Maven

### 2.1. Корневой `pom.xml`, блок `<properties>` — добавить

```xml
<openapi-generator.version>7.18.0</openapi-generator.version>
```

### 2.2. Корневой `pom.xml`, блок `<build><pluginManagement><plugins>` — добавить плагин

```xml
<plugin>
    <groupId>org.openapitools</groupId>
    <artifactId>openapi-generator-maven-plugin</artifactId>
    <version>${openapi-generator.version}</version>
    <executions>
        <execution>
            <id>generate-server-api</id>
            <goals>
                <goal>generate</goal>
            </goals>
            <configuration>
                <inputSpec>${project.basedir}/../openapi.yaml</inputSpec>
                <generatorName>spring</generatorName>
                <output>${project.build.directory}/generated-sources/openapi</output>
                <apiPackage>ru.sbrf.gmap.vux.api</apiPackage>
                <modelPackage>ru.sbrf.gmap.vux.api.model</modelPackage>
                <modelNameSuffix>Dto</modelNameSuffix>
                <generateApiTests>false</generateApiTests>
                <generateModelTests>false</generateModelTests>
                <generateApiDocumentation>false</generateApiDocumentation>
                <generateModelDocumentation>false</generateModelDocumentation>
                <generateSupportingFiles>false</generateSupportingFiles>
                <configOptions>
                    <interfaceOnly>true</interfaceOnly>
                    <skipDefaultInterface>true</skipDefaultInterface>
                    <useSpringBoot3>true</useSpringBoot3>
                    <useJakartaEe>true</useJakartaEe>
                    <useBeanValidation>true</useBeanValidation>
                    <useTags>true</useTags>
                    <openApiNullable>false</openApiNullable>
                    <documentationProvider>none</documentationProvider>
                    <annotationLibrary>none</annotationLibrary>
                </configOptions>
            </configuration>
        </execution>
    </executions>
</plugin>
```

Важно: `${project.basedir}` при выполнении — это каталог модуля `service`, поэтому путь `../openapi.yaml` указывает на корень проекта.

### 2.3. `service/pom.xml`, блок `<build><plugins>` — добавить ссылку на плагин (без версии и конфигурации)

```xml
<plugin>
    <groupId>org.openapitools</groupId>
    <artifactId>openapi-generator-maven-plugin</artifactId>
</plugin>
```

### 2.4. Проверка

Выполнить `mvn -pl service -am generate-sources` и убедиться, что появились файлы:
- `service/target/generated-sources/openapi/src/main/java/ru/sbrf/gmap/vux/api/UploadApi.java`
- `service/target/generated-sources/openapi/src/main/java/ru/sbrf/gmap/vux/api/model/UploadByS3PathRequestDto.java`
- `service/target/generated-sources/openapi/src/main/java/ru/sbrf/gmap/vux/api/model/DocumentTypeDto.java`

---

## Шаг 3. Переписать `UploadController`

Файл: `service/src/main/java/ru/sbrf/gmap/vux/controller/UploadController.java`. Полностью заменить содержимое на:

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
        DocumentTypeEnum documentType = DocumentTypeEnum.valueOf(request.getDocumentType().name());
        UUID rqUid = uploadDocumentService.uploadDocumentViaTfsByS3Path(
                request.getS3Path(),
                request.getFilename(),
                documentType,
                request.getSliceId()
        );
        log.info("Document by S3 path '{}' accepted for upload, rqUid: '{}'", request.getS3Path(), rqUid);
        return ResponseEntity.ok(rqUid);
    }
}
```

Обязательно:
- **Убрать** `@RequestMapping("/api/v1/upload")` с класса: полный путь уже задан в `UploadApi`, иначе путь задвоится.
- **Не** повторять `@PostMapping`, `@Valid`, `@RequestBody` в реализации: Spring берёт их из интерфейса.
- Удалить метод `resolveDocumentType`. Маппинг `DocumentTypeDto → DocumentTypeEnum` делается через `valueOf(dto.name())`, имена констант совпадают.
- Если имя параметра или тип ответа в сгенерированном `UploadApi` отличаются от примера, привести сигнатуру к интерфейсу.

---

## Шаг 4. Удалить старый DTO

Удалить файл `service/src/main/java/ru/sbrf/gmap/vux/dto/request/ecm/UploadByS3PathRequestDto.java`.

Перед удалением выполнить поиск по проекту `UploadByS3PathRequestDto` с пакетом `ru.sbrf.gmap.vux.dto.request.ecm`. Если кроме `UploadController` и `UploadControllerTest` есть другие использования — НЕ удалять и сообщить об этом.

---

## Шаг 5. Обновить unit-тест контроллера

Файл: `service/src/test/java/ru/sbrf/gmap/vux/controller/UploadControllerTest.java`. Заменить содержимое на:

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
import ru.sbrf.gmap.vux.api.model.DocumentTypeDto;
import ru.sbrf.gmap.vux.api.model.UploadByS3PathRequestDto;
import ru.sbrf.gmap.vux.model.DocumentTypeEnum;
import ru.sbrf.gmap.vux.service.UploadDocumentService;

import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
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
                .documentType(DocumentTypeDto.XBRL_DOCUMENT)
                .sliceId("slice-1");

        ResponseEntity<UUID> response = uploadController.uploadByS3Path(request);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(response.getBody()).isEqualTo(rqUid);
    }

    @Test
    @DisplayName("каждый DocumentTypeDto маппится на DocumentTypeEnum")
    void documentTypeDto_allValuesMapToDomainEnum() {
        for (DocumentTypeDto dto : DocumentTypeDto.values()) {
            assertThat(DocumentTypeEnum.valueOf(dto.name())).isNotNull();
        }
    }
}
```

Старый тест `uploadByS3Path_invalidDocumentType_throws` удаляется: неизвестную строку в enum передать нельзя, эту проверку теперь выполняет HTTP-слой (см. шаг 6). Тест `documentTypeDto_allValuesMapToDomainEnum` упадёт, если yaml и `DocumentTypeEnum` разойдутся.

---

## Шаг 6. Добавить HTTP-тест контроллера (MockMvc standalone)

Новый файл: `service/src/test/java/ru/sbrf/gmap/vux/controller/UploadControllerWebTest.java`.

Тест без поднятия Spring-контекста (`standaloneSetup`), чтобы не требовались БД, Kafka и S3. Проверяет валидацию и коды ответа.

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

import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
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
                .andExpect(content().string("\"" + rqUid + "\""));
    }

    @Test
    @DisplayName("неизвестный documentType: 400")
    void unknownDocumentType_returns400() throws Exception {
        mockMvc.perform(post(URL)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"s3Path":"folder/file.pdf","filename":"file.pdf","documentType":"WRONG","sliceId":"slice-1"}
                                """))
                .andExpect(status().isBadRequest());
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
                .andExpect(status().isBadRequest());
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
                .andExpect(status().isBadRequest());
        verifyNoInteractions(uploadDocumentService);
    }
}
```

Если в проекте нет `org.springframework.test.web.servlet` (spring-test), он приходит из уже подключённого `spring-boot-starter-test` — новых зависимостей не добавлять. Если тест на успешный ответ падает только из-за формата тела (например, кавычки), поправить проверку тела, но не менять поведение контроллера.

---

## Шаг 7. Финальная проверка

1. `mvn clean verify` из корня проекта — сборка и все тесты проходят.
2. В IDE: Maven → Reload Project, классы `UploadApi`, `UploadByS3PathRequestDto`, `DocumentTypeDto` видны.
3. В коде не осталось импортов `ru.sbrf.gmap.vux.dto.request.ecm.UploadByS3PathRequestDto`.
4. На классе `UploadController` нет `@RequestMapping`.
5. Предупреждения компиляции про устаревший `org.springframework.lang.Nullable` в сгенерированном коде допустимы (в Spring 7 аннотация помечена deprecated), это не ошибка.

---

## Ожидаемое поведение после изменений (для справки)

| Запрос | Ответ |
|---|---|
| Валидное тело | 200, `application/json`, тело `"<uuid>"` (как раньше) |
| `documentType` не из списка | 400, `application/problem+json`, detail `Malformed request body` (раньше было `Unknown documentType: '...'`) |
| Пустая или пробельная строка в `s3Path`/`filename`/`sliceId` | 400, detail `Request validation failed` (как раньше) |
| Нет обязательного поля | 400, detail `Request validation failed` (как раньше) |
| Ошибка ECM/S3 | 500, `application/problem+json` (как раньше) |

Единственное изменение для вызывающей стороны — текст `detail` при неверном `documentType`. Статус-код не меняется.

## Итоговый список изменённых файлов

- `openapi.yaml` (новый, корень проекта)
- `pom.xml` (корневой: свойство + плагин в pluginManagement)
- `service/pom.xml` (подключение плагина)
- `service/src/main/java/ru/sbrf/gmap/vux/controller/UploadController.java` (переписан)
- `service/src/main/java/ru/sbrf/gmap/vux/dto/request/ecm/UploadByS3PathRequestDto.java` (удалён)
- `service/src/test/java/ru/sbrf/gmap/vux/controller/UploadControllerTest.java` (обновлён)
- `service/src/test/java/ru/sbrf/gmap/vux/controller/UploadControllerWebTest.java` (новый)

## Дальнейшая работа с API

Любое изменение API начинается с правки `openapi.yaml`. После правки — `mvn compile`: компилятор покажет, что нужно поправить в контроллере. Этот же `openapi.yaml` используется Schemathesis для контрактного тестирования на FAT.
