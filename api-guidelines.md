# General API Guidelines
## [Podejście API First (pzu:general1:2025-api-first)](#api-first)

Każdy **POWINIEN** przestrzegać zasady **API First**. Zasada API First jest rozszerzeniem zasady **design-first**. Dlatego rozwój API **POWINIEN** zawsze zaczynać się od projektu API bez żadnych wstępnych działań związanych z kodowaniem. Projekt API (np. opis, schema) jest **źródłem prawdy**, a nie implementacja API. Implementacja API **MUSI** zawsze być zgodna z konkretnym projektem API, który reprezentuje kontrakt między API a jego konsumentem.

---

---

## [Język (pzu:general2:2025-language)](#language)

TBD.

---

## [Terminologia (pzu:general3:2025-terminology)](#terminology)

- **Specyfikacja API** - odnosi się do do formatu specyfikacji, takiego jak OpenAPI lub AsyncAPI, ale nie do dokumentu utworzonego przy użyciu takiej specyfikacji.

- **Dokument API/Opis API/Dokument Opisu API** - odnosi się do dokumentu opisującego projekt API przy użyciu specyfikacji takiej jak OpenAPI.

- **Schema** - odnosi się do opisu modelu danych. Zazwyczaj jest tworzony w specyfikacji takiej jak JSON-Schema, Avro Schema lub Protobuff.

- **Projekt API** - odnosi się do formalnego opisu API. Nie musi, lecz może, odnosić się do Dokumentu Opisu API.

---

## [Nowe i istniejące API (pzu:general4:2025-new-existing-APIs)](#new-vs-existing)

Dla wszystkich nowo powstających API **MUSZĄ** być spełnione wszystkie [zasady API Guidelines](/) w wyszczególnionym zakresie (MUSI/POWINIEN/MOŻE)<!-- i [zasady projektowe API asynchornicznych]()-->.

Dla już istniejących API, [zasady API Guidelines](/) **POWINNY** być spełnione.

## [Semver (pzu:general5:2025-semver)](#semver)

API MUSI używać Semantic Versioning (SemVer) w formacie MAJOR.MINOR.PATCH jako jedynego dozwolonego oznaczania wersjonowania.

### Elementy wersji

- **MAJOR**: Inkrementowany przy wprowadzaniu zmian niekompatybilnych wstecz.
- **MINOR**: Inkrementowany przy dodawaniu nowej funkcjonalności _potencjalnie_ kompatybilnej wstecz.
- **PATCH**: Inkrementowany przy wprowadzaniu poprawek błędów kompatybilnych wstecz.

> **Potencjalna wsteczna kompatybilność:** mówimy o **potencjalnej** kompatybilności wstecznej, ponieważ może zdarzyć się tak, że zmiany kompatybilne wstecz takie nie będą, np. ze względu na ścisłe ograniczenia klienta jak rozmiar wiadomości. Z tego powodu nie da się zagwarantować twardej kompatybilności wstecznej.

---

## [Kontrakt (pzu:general6:2025-contract)](#api-contract)

Zatwierdzony **projekt API**, reprezentowany przez jego **dokument API** lub schema, **MUSI** stanowić kontrakt między interesariuszami API, "providerami" i konsumentami. Aktualizacja odpowiedniego kontraktu (**projektu API**) **MUSI** być zaimplementowana w jego opisie i zatwierdzona przed wprowadzeniem jakichkolwiek zmian w implementacji API.

<!-- 
---

### Niezmienność

Po uzgodnieniu z interesariuszami, kontrakt **MUSI** zostać opublikowany w **rejestrze API**, aby uczynić go (tę wersję) stałym. Rejestr API działa jako centralne miejsce do przechowywania i dostępu do wszystkich opublikowanych API.-->

---

## [Niezawodność (pzu:general7:2025-robustness)](#robustness)

Każda implementacja API i każdy konsument API **MUSI** przestrzegać **prawa Postela**:

> Bądź konserwatywny w tym, co wysyłasz, bądź liberalny w tym, co akceptujesz.
> 
> – [John Postel](https://en.wikipedia.org/wiki/Robustness_principle)

Oznacza to, że należy wysyłać niezbędne minimum i być jak najbardziej tolerancyjnym podczas korzystania z innej usługi ([tolerancyjny czytelnik](https://martinfowler.com/bliki/TolerantReader.html)).

---

## [System Kontroli Wersji (pzu:general8:2025-version-control)](#version-control)

Każdy projekt API **MUSI** być przechowywany w Systemie Kontroli Wersji (np. Bitbucket, GitHub). Tam, gdzie to możliwe, projekt API **POWINIEN** być przechowywany w tym samym repozytorium co implementacja API. W przypadku ścisłych zasad bezpieczeństwa związanych z dostępem do repozytorium zawierającego implementację API, kontrakt API **POWINIEN** być dostępny dla interesariuszy do wglądu w innym miejscu.

---

## [Minimalna Powierzchnia API (pzu:general9:2025-yagni)](#yagni)

Każdy projekt API **MUSI** dążyć do minimalnej powierzchni API bez poświęcania wymagań produktowych. Projekt API **NIE POWINIEN** zawierać zbędnych zasobów, relacji, akcji lub danych. Projekt API **NIE POWINIEN** dodawać funkcjonalności, dopóki nie zostanie to uznane za konieczne (zasada [YAGNI](https://en.wikipedia.org/wiki/You_aren%27t_gonna_need_it)).

---

## [Zasady rozszerzania (pzu:general10:2025-rules-of-extension)](#rules-of-extension)

Każda modyfikacja istniejącego API **MUSI** unikać wprowadzania zmian łamiących zgodność i **MUSI** zachować wsteczną kompatybilność. W przypadku, gdy istnieje potrzeba złamania kompatybilności wstecznej, API **MUSI** również zmienić swoją wersję **major**.

W szczególności, każda zmiana w API **MUSI** przestrzegać następujących Zasad Rozszerzania:

- **NIE MOŻNA** niczego usuwać (powiązane: [Zasada minimalnej powierzchni](https://en.wikipedia.org/wiki/YAGNI), [Zasada solidności](https://en.wikipedia.org/wiki/Robustness_principle))
- **NIE MOŻNA** zmieniać reguł przetwarzania
- **NIE MOŻNA** czynić opcjonalnych rzeczy wymaganymi
- Wszystko, co dodajesz, **MUSI** być opcjonalne (powiązane: [Zasada solidności](https://en.wikipedia.org/wiki/Robustness_principle))

> UWAGA: Te zasady obejmują również zmianę nazw i identyfikatorów (URI). Nazwy i identyfikatory powinny być stabilne w czasie, włącznie z ich semantyką.

---

## [JSON (pzu:general11:2025-json)](#json)

Każda wiadomość oparta na JSON **MUSI** być zgodna z następującymi zasadami:

- Wszystkie nazwy pól JSON **MUSZĄ** przestrzegać [Konwencji Nazewnictwa]()
- Nazwy pól **MUSZĄ** składać się z alfanumerycznych znaków ASCII, podkreślenia (_) lub znaku dolara ($)
- Pola logiczne **NIE MOGĄ** mieć wartości `null`
- Pola z wartością `null` **POWINNY** być pomijane
- Puste tablice i obiekty **NIE MOGĄ** być `null` (zamiast tego użyj `[]` lub `{}`)
- Nazwy pól będących tablicami **POWINNY** być w liczbie mnogiej (np. `"orders": []`)

<!--
### Walidacja

Wszystkie API **MUSZĄ** walidować swój payload w zapytaniach/odpowiedziach za pomocą JSON Schema dla zdefiniowanej struktury przed publikacją Kontraktu API.

Publikacja schematu JSON odpowiadającego oczekiwanym payloadom w treściach żądań i odpowiedzi **POWINNA** być aktualizowana zgodnie z ewolucją API.
-->

---

## [Jedno Źródło Prawdy (pzu:general12:2025-single-source-of-truth)](#single-source-of-truth)
<!--
Azure API Center jest główną platformą wspierającą podejście API-first. Azure API Center **MUSI** być używany podczas projektowania API.

Każdy opis API **MUSI** być przechowywany w Azure API Center w ramach zespołu PZU. -->

Pliki schematów definicji interfejsów, takie jak:

- OpenAPI Specification(OAS)/Swagger
- GraphQL Schema Definition Language (SDL)
- Web Service Description Language (WSDL)
- Avro Schema automatycznie

i im podobne, znajdujące się w repozytorium projektu **MUSZĄ** być jedynym źródłem prawdy dla definicji API.

<!-- Azure API Center **POWINIEN** być zasilany bezpośrednio z repozytorium projektu plikiem projektowym, takim jak 

UWAGA: Azure API Center wspiera podejście API-first na wiele sposobów:
Na przykład, waliduje poprawność opisu API oraz automatycznie generuje dokumentację API, co ułatwia dyskusję między interesariuszami. (Koniec z wymianą e-maili z opisem API między interesariuszami) -->

# API Guidelines dla REST

Wytyczne REST API PZU definiują standardy i wskazówki dotyczące budowania interfejsów REST API w PZU. Wytyczne te muszą być przestrzegane razem z Ogólnymi Wytycznymi Projektowymi API PZU.

## [OpenAPI Specification (pzu:rest1:2025-openapi)](#open-api-specification)

Każde API **MUSI** być opisane przy użyciu formatu opisu OpenAPI. Używany format OpenAPI **MUSI** być zgodny ze [specyfikacją OpenAPI (wcześniej znaną jako Swagger Specification) w wersji 3.x.y](https://github.com/OAI/OpenAPI-Specification/blob/main/versions/3.1.1.md). Jeśli to możliwe, format opisu API **POWINIEN** być zgodny ze specyfikacją 3.1.x, ze względu na pełną kompatybilność z formatem JSON-Schema.

### `info.version` w OpenAPI (pzu:rest2:2025-openapi-version)

Element `info.version` w dokumencie OpenAPI **MUSI** określać wersję dokumentu API. Ta wersja nie jest tym samym, co wersja API.

---

## [Dojrzałość Projektowania API (pzu:rest3:2025-design-maturity-wadmm)](#maturity-wadmm)

> Jak zaprojektować API

Każdy projekt API **MUSI** być zorientowany na zasoby ([Poziom 2 Web API Design Maturity Model](http://amundsen.com/talks/2016-11-apistrat-wadm/2016-11-apistrat-wadm.pdf)). Oznacza to, że projekt API **MUSI** opierać się na zasobach w stylu Web, relacjach między tymi zasobami oraz działaniach, które mogą być przez nie oferowane.

Projekt API **POWINIEN** być zorientowany na funkcję użytkową ([Poziom 3 Modelu Dojrzałości Projektowania Web API](http://amundsen.com/talks/2016-11-apistrat-wadm/2016-11-apistrat-wadm.pdf)).

---

## [Dojrzałość Implementacji Projektu API (pzu:rest4:2025-design-maturity-rmm)](#maturity-rmm)

Każda implementacja projektu API korzystająca z protokołu HTTP **MUSI** używać odpowiedniej metody żądania HTTP ([Poziom 2 Modelu Dojrzałości Richardsona](https://martinfowler.com/articles/richardsonMaturityModel.html#level2)) do realizacji działania oferowanego przez zasób.

Implementacja projektu API **POWINNA** zawierać kontrolki hypermedia (HATEOAS) ([Poziom 3 Modelu Dojrzałości Richardsona](https://martinfowler.com/articles/richardsonMaturityModel.html#level3)).

<!-- 
---

## [Testowanie kontraktowe](#contract-testing)

Każda implementacja API REST **MUSI** być przetestowana względem swojego kontraktu, czyli projektu API w formacie OpenAPI.
-->
---

## [Konwencje Nazewnictwa ](#naming-conventions)

Poniższe konwencje nazewnictwa odnoszą się do formatu opisu API.

### [Ogólne Zasady Nazewnictwa (pzu:rest5:2025-general-naming-conventions)](#general-naming-conventions)

Każdy identyfikator **MUSI** być zapisany małymi literami.

Identyfikator **NIE POWINIEN** zawierać akronimów biznesowych.

Do oddzielania złożonych słów **MUSI** być używana konwencja `camelCase` (np. `itemIdentifier`).  

### [URI (pzu:rest6:2025-uri-naming-conventions)](#uri-naming-conventions)  

Każdy URI **MUSI** przestrzegać Ogólnych Zasad, z wyjątkiem konwencji `camelCase`. Zamiast tego, do oddzielania złożonych słów **MUSI** być używany łącznik (-) (konwencja `kebab-case`). Ponadto URI **NIE MOŻE** kończyć się ukośnikiem (/). <!-- a co z przykładami, gdy identyfikator zawiera /? -->

Rzeczowniki w liczbie mnogiej **POWINNY** być używane w URI, aby identyfikować kolekcje zasobów danych (np. `/orders`, `/products`).

Pojedynczy zasób w kolekcji zasobów **MOŻE** istnieć bezpośrednio pod URI kolekcji (np. `/orders/{order_id}`).

<!-- jak adresować problem wielu bardzo długich identyfikatorów, limit w URI jest 1024 znaków -->

#### Przykład

Poprawnie sformułowany URI:  

```text
/system-orders/1234/author
```

### [Parametry Zapytania i Fragmenty Ścieżki (pzu:rest7:2025-paths-naming-conventions)](#parameters-paths-naming-conventions)  

Każdy parametr zapytania URI lub fragment **MUSI** przestrzegać Ogólnych Zasad. Dodatkowo **NIE MOGĄ** one kolidować z zastrzeżonymi nazwami parametrów zapytania, np `offset` dla stronicowania, lub parametrów zarezerwowanych przez używane.

<!-- doprecyzować jakie są zastrzeżone parametry; czy sa zastrzeżone zawsze, czy jako konwencja/best practice -->

#### [Zmienne Szablonu URI (pzu:rest8:2025-path-params-naming-conventions)](#path-params-naming-conventions)

Oprócz Ogólnych Zasad Nazewnictwa, nazwy zmiennych szablonu URI **MUSZĄ** być zgodne z [RFC6570](https://datatracker.ietf.org/doc/html/rfc6570#section-2.3). Oznacza to, że nazwy zmiennych mogą składać się wyłącznie z symboli `ALPHA / DIGIT / "_" / pct-encoded`.

<!-- Kiedy jest możliwość, aby w szablonach URI był pct-encoded? -->

> **UWAGA:** Zgodnie z RFC6570 znak łącznika (-) NIE jest dozwolonym znakiem dla nazw zmiennych szablonu URI.  

#### Przykład  

Poprawnie sformułowana zmienna szablonu URI:  

```text
/system-orders/{orderId}/author
```

### [Format Pola Reprezentacji (pzu:rest9:2025-representation-format-naming-conventions)](#representation-format-naming-conventions)

Każde pole formatu reprezentacji **MUSI** być zgodne z Ogólnymi Zasadami Nazewnictwa.

#### Przykład
Poprawnie sformułowana reprezentacja zasobu:  

```json
{
  "_links": {
    "self": {
      "href": "/orders/1234"
    },
    "author": {
      "href": "/users/john"
    }
  },
  "orderNumber": 1234,
  "itemCount": 42,
  "status": "pending"
}
```
<!--
### [Identyfikator Typu Relacji](#relation-type-naming-conventions)

Każdy niestandardowy identyfikator relacji **MUSI** być zapisany małymi literami, a słowa oddzielone łącznikiem (-).  

#### Przykład

Poprawnie sformułowana reprezentacja zasobu z niestandardową relacją fulfillment-provider:  

```json
{
  "_links": {
    "fulfillment-provider": {
      "href": "/users/natalie"
    }
  }
}
```
-->
### [Nagłówki HTTP (pzu:rest10:2025-headers-naming-conventions)](#headers-naming-conventions)

Każdy nagłówek HTTP **POWINIEN** stosować konwencję `Hyphenated-Pascal-Case`. Niestandardowy nagłówek HTTP **NIE POWINIEN** zaczynać się od `X-` (zgodnie z [RFC6648](https://datatracker.ietf.org/doc/html/rfc6648)).

#### Przykład

```text
Order-Metadata-Header: 42
```

---

## [Opis API](#api-description)

### [Nazwa API (pzu:rest11:2025-api-naming)](#api-naming) 

Każda nazwa API w dokumencie opisu API **MUSI** być zapisana w konwencji **Title Case**, czyli każdy wyraz **MUSI** zaczynać się od wielkiej litery. Ponadto, każda nazwa API **MUSI** kończyć się słowem `API`. Tytuł API **NIE POWINIEN** zawierać akronimów biznesowych i skrótów, np. `Ubezpieczenia GR API` lub `Szko Lik API`.

#### Przykład

```yaml
openapi: '3.1.0'
info:
  version: '1.0.0'
  title: 'Customer Orders API'
```

### [Nazwa Zasobu (pzu:rest12:2025-resource-name)](#resource-name)

Każdy zasób (endpoint) **MUSI** mieć nazwę (zdefiniowaną w polu `summary`). Nazwa zasobu **MUSI** być zapisana w **Title Case**, a słowa oddzielone spacją. Nazwa zasobu **NIE POWINNA** zawierać akronimów biznesowych i skrótów, np. `Lista GR` lub `Lista Ub`.

#### Przykład

```yaml
/orders:
  summary: List of Orders
```

### [Nazwa operacji (pzu:rest13:2025-operation-name)](#operation-name)

Każda operacja (akcja) **MUSI** mieć nazwę (zdefiniowaną w polu `summary`). Nazwa akcji **MUSI** być zapisana w **Title Case**, a słowa oddzielone spacją. Nazwa operacji **NIE POWINNA** zawierać akronimów biznesowych i skrótów, np. `Uaktualnij listę GR` lub `Usuń Ub`.

#### Przykład

```yaml
get:
  summary: Retrieve List of Orders
```

### [Opis operacji (pzu:rest14:2025-operation-description)](#operation-description)

Każda operacja (akcja) **POWINNA** mieć opis (zdefiniowaną w polu `description`). Każdy opis **POWINIEN** mieć długość przynajmniej 30 znaków. Opis **MOŻE** być w formacie Markdown.

#### Przykład

```yaml
get:
  summary: Retrieve List of Orders
  description: Retrieve a list of all orders in the store. You can filter orders by date and customer.

```

---
<!-- do sprawdzenia, dodać przykład -->
## [Struktura URI (pzu:rest15:2025-uri-structure)](#uri-structure)

URI służy do wyrażania tożsamości zasobu. URI jest identyfikatorem i **NIE MOŻE** przekazywać żadnych innych informacji.

W PZU URI podlegają konwencjom nazewnictwa opisanym powyżej.

Aby dowiedzieć się więcej na temat tej problematyki, zapoznaj się z dokumentem [RFC 7320: URI Design and Ownership](https://tools.ietf.org/html/rfc7320).
<!-- do tąd -->
---

## [HTTP (pzu:rest16:2025-http)](#http)

Każde API **MUSI** obsługiwać co najmniej [HTTP/1.1](https://www.rfc-editor.org/rfc/rfc9112) i **MUSI** przestrzegać jego semantyki. <!-- API **MOŻE** obsługiwać HTTP/2 lub HTTP/3. (dodac linki) -->

### [HTTPS (pzu:rest17:2025-https)](#https)

Każde API **MUSI** wymagać bezpiecznych połączeń z użyciem [TLS w wersji przynajmniej 1.2](https://datatracker.ietf.org/doc/html/rfc5246). **MOŻE** używać [TLS 1.3](https://datatracker.ietf.org/doc/html/rfc8446). Oznacza to, że API korzystające z protokołu HTTP **MUSI** używać HTTPS.

Wszelkie żądania bez TLS **POWINNY** być ignorowane. W środowiskach HTTP, gdzie nie jest to możliwe, żądanie bez TLS **POWINNO** skutkować odpowiedzią `403 Forbidden`.

---

## [Separacja Zagadnień (pzu:rest18:2025-separation-of-concerns)](#separation-of-concerns)

Każde API korzystające z HTTP **MUSI** ściśle przestrzegać separacji zagadnień w wiadomości HTTP:

I. *Identyfikator zasobu (URI)* **POWINIEN** być używany wyłącznie do wskazania tożsamości <!-- docelowo MUSI -->
II. *Metoda żądania HTTP* **MUSI** być używana do komunikowania semantyki działania (intencja i bezpieczeństwo)
III. *Kod statusu odpowiedzi HTTP* **MUSI** być używany do przekazywania informacji o wyniku próby zrozumienia i spełnienia żądania
IV. *Treść wiadomości HTTP* **MUSI** być używana do przesyłania zawartości wiadomości
V. *Nagłówki wiadomości HTTP* **MUSZĄ** być używane do przesyłania metadanych o wiadomości i jej zawartości
VI. *Parametr zapytania URI* **NIE POWINIEN** być używany do przesyłania metadanych

### Przykłady

Znajdują się na [stronie dobrych praktyk, w dziale "Separacja Zagadnień"](/best-practices#separation-of-concerns).

---

## [Metody zapytań](#request-methods)

Każde API **MUSI** używać poprawnych [metod HTTP](https://github.com/for-GET/know-your-http-well/blob/master/methods.md) dla każdej operacji.

Każdy użytkownik (_provider_, _konsument_, itd.) API **MUSI** rozumieć semantykę metody HTTP, której używa.

Wszyscy **MUSZĄ** być zaznajomieni z semantyką ["powszechnych" metod żądań HTTP](https://github.com/for-GET/know-your-http-well/blob/master/methods.md#common): **DELETE**, **GET**, **HEAD**, **PUT**, **POST** oraz [**PATCH**](https://tools.ietf.org/html/rfc5789#section-2). Ponadto, każdy **MUSI** wiedzieć, które metody są [**bezpieczne**](/rest#safe-methods), [**idempotentne**](/rest#idempotency) i [**możliwe do buforowania**](/rest#cacheable-methods).

### [Metody Bezpieczne](#safe-methods)

Zgodnie ze specyfikacją HTTP, metody **GET** i **HEAD** powinny być używane wyłącznie do pobierania reprezentacji zasobów – nie aktualizują/usuwają zasobów na serwerze. Obie metody są uważane za „bezpieczne”. To pozwala agentom użytkownika na specjalne reprezentowanie innych metod, takich jak POST, PUT i DELETE, aby użytkownik był świadomy potencjalnie niebezpiecznego działania – mogą one aktualizować/usunąć zasób na serwerze i dlatego powinny być używane ostrożnie.

### [Metody Idempotentne](#idempotency)

Termin idempotentność opisuje operację, która da takie same wyniki przy jednokrotnym lub wielokrotnym wykonaniu. Jest to korzystna cecha w wielu sytuacjach, ponieważ oznacza, że transakcję można powtarzać lub próbować ponownie tyle razy, ile to konieczne, bez powodowania niezamierzonych skutków. W specyfikacji HTTP metody **GET**, **HEAD**, **PUT** i **DELETE** są uznawane za idempotentne. Inne metody **OPTIONS** i **TRACE** **NIE POWINNY** mieć skutków ubocznych, więc obie są również z natury idempotentne. **NIE MOŻNA** implementować metod HTTP z inną idempotentnością niż jest to zdefiniowane domyślnie.

### [Metody Buforowalne](#cacheable-methods)

Metody żądań są uważane za _buforowalne_ (ang. cacheable), jeśli możliwe i użyteczne jest odpowiedzenie na bieżące żądanie klienta przechowywaną odpowiedzią z wcześniejszego żądania. **GET** i **HEAD** są zdefiniowane jako buforowalne.

#### Przykład 1

```text
GET /user/new Opis: Tworzy nowego użytkownika
```

Używanie GET do operacji niebezpiecznych i nieidempotentnych jest **niedopuszczalne**.

#### Przykład 2

```text
POST /status Opis: Aktualizuje status prośby o zatwierdzenie użytkownika (na „Approved” lub „Rejected”)
```

Używanie metody POST do aktualizacji statusu jest **niedopuszczalne** (należy użyć PATCH).

#### Przykład 3

```text
PUT /user Opis: Tworzy nowego użytkownika
```

Używanie metody PUT do tworzenia nowego zasobu jest ***niedopuszczalne*** (należy użyć POST).

#### Przykład 4

```text
PUT: /user Opis: Aktualizuje niektóre szczegóły użytkownika
```

Używanie metody PUT do częściowej aktualizacji jest **niedopuszczalne** (należy użyć PATCH).

---

## [Kody Statusu Odpowiedzi (ang. Response Status Codes) (pzu:rest18:2025-separation-of-concerns)](#status-codes)

Każde API **MUSI** używać odpowiednich [kodów statusu HTTP](https://github.com/for-GET/know-your-http-well/blob/master/status-codes.md), aby komunikować wynik operacji żądania.

Każdy projektant, wdrożeniowiec i użytkownik API **MUSI** rozumieć semantykę kodu statusu HTTP, którego używa.
Wszyscy **POWINNI** być zaznajomieni z semantyką [_powszechnych_ kodów statusu HTTP](https://github.com/for-GET/know-your-http-well/blob/master/status-codes.md#common).

### [Używaj kodów 4xx lub 5xx do komunikowania błędów (pzu:rest19:2025-error-codes)](#error-codes)

Zakres `4xx` dotyczy błędów po stronie konsumenta/klienta API, podczas gdy zakres `5xx` dotyczy błędów w usłudze infrastruktury lub implementacji API.

Żądanie:

```text
GET /orders/1234 HTTP/1.1
...
```

zakończone odpowiedzią `200 OK`, gdy żądany zasób (zidentyfikowany przez URI żądania) nie został znaleziony:

```text
HTTP/1.1 200 OK
Content-Type: application/json
...

{
    "code": "NOT_FOUND_ERR_CODE",
    "message": "Order 1234 wasn't found"
}
```

jest ***niedopuszczalne***.

Zamiast tego powinno zostać zwrócone:

```text
HTTP/1.1 404 Not Found
...
```

### Zalecana Lektura

[Jak myśleć o kodach statusu HTTP](https://www.mnot.net/blog/2017/05/11/status_codes)

---

## [Format Wiadomości](#message-format)

### [Format Odpowiedzi na Błąd (pzu:rest20:2025-problem-detail)](#problem-detail)

Format `application/problem+json` (Problem Detail) **MUSI** być używany do komunikowania szczegółów dotyczących błędu.

Problem Detail jest przeznaczony do użycia z kodami statusu HTTP 4xx i 5xx. Problem Detail **NIE MOŻE** być używany z odpowiedziami o kodzie statusu 2xx.

Każda odpowiedź Problem Detail **MUSI** zawierać pola `title` i `detail`. Wartość `title` **NIE POWINNA** zmieniać się przy każdym wystąpieniu problemu, z wyjątkiem celów lokalizacyjnych (np. używając proaktywnej negocjacji zawartości).

#### Przykład

```json
{
  "title": "Authentication required",
  "detail": "Missing authentication credentials for the Greeting resource."
}
```

> UWAGA: Pola `title` i `detail` **NIE POWINNY** być analizowane w celu określenia natury błędu. Zamiast tego **MUSI** być używane pole `type`.

#### Pola Opcjonalne

Każda odpowiedź Problem Detail powinna mieć pole `type` z identyfikatorem błędu. Ponadto **MOŻE** mieć pole `instance` z URI zasobu, którego dotyczy. Jeśli odpowiedź Problem Detail zawiera pole `status`, **MUSI** mieć tę samą wartość co kod Statusu HTTP odpowiedzi.

```json
{
  "type": "https://api.pzu.pl/problems/scv/unauthorized",
  "title": "Authentication required",
  "detail": "Missing authentication credentials for the Greeting resource.",
  "instance": "/greeting",
  "status": 401
}
```

> UWAGA: Pole `type` jest identyfikatorem i jako takie **MOŻE** być używane do oznaczania dodatkowych kodów błędów. Należy pamiętać, że identyfikator powinien być URI.

#### Dodatkowe Pola

Jeśli to konieczne, Problem Detail **MOŻE** zawierać dodatkowe pola, szczegóły znajdują się w [RFC9457](https://www.rfc-editor.org/rfc/rfc9457).

### [Format Wiadomości Żądania (pzu:rest20:2025-message-json)](#message-json)

Wiadomości żądania z treścią **MUSZĄ** obsługiwać format `application/json (JSON)`.

## [Negocjacja Zawartości (ang. Content Negotiation) (pzu:rest21:2025-content-negotiation)](#content-negotiation)

Każde API **MUSI** implementować, a każdy Konsument API **MUSI** używać [negocjacji zawartości HTTP](https://tools.ietf.org/html/rfc7231#section-3.4), **gdy żądana jest reprezentacja zasobu**.

> UWAGA: Negocjacja zawartości odgrywa kluczową rolę w ewolucji API, zarządzaniu zmianami i wersjonowaniu.

#### Przykład

Klient jest zaprogramowany do rozumienia semantyki formatu wiadomości `application/vnd.example.resource+json; version=2`. Klient żąda reprezentacji zasobu `/greeting` w pożądanym typie mediów (w tym jego wersji) od serwera:

```text
GET /greeting HTTP/1.1
Accept: application/vnd.example.resource+json; version=2
...
```

Serwer może dostarczyć tylko nowszą wersję żądanego typu mediów `version=2.1.3`. Jednakże, ponieważ nowsza wersja jest kompatybilna wstecz z żądaną wersją `version=2` (zobacz: [Zmiany i Wersjonowanie](./#zmiany-i-wersjonowanie)), może spełnić żądanie i odpowiada:

```text
HTTP/1.1 200 OK
Content-Type: application/vnd.example.resource+json; version=2.1.3
...
```

> UWAGA: Serwer, który nie ma dostępnej żądanej reprezentacji typu mediów, **MUSI** odpowiedzieć kodem statusu HTTP **406 Not Acceptable**.

> UWAGA: Serwer **MOŻE** mieć dostępne wiele opcji i **MOŻE** odpowiedzieć odpowiedzią **300 Multiple Choices**. W takim przypadku klient **POWINIEN** wybrać spośród przedstawionych opcji.

Więcej o negocjacji zawartości można przeczytać na stronie [MDN Content negotiation](https://developer.mozilla.org/en-US/docs/Web/HTTP/Content_negotiation).

---

## [Typy Danych](#data-formats)

### [Format Daty i Czasu (pzu:rest22:2025-date-time-format)](#date-time-format)

Data i czas **MUSZĄ** zawsze być zgodne z formatem [ISO 8601](https://pl.wikipedia.org/wiki/ISO_8601), np.: `2017-06-21T14:07:17Z` (data i czas) lub `2017-06-21` (data)<!--, **MUSZĄ** używać UTC (bez przesunięć czasowych) - tu musimy ustalić jaką strefę czasową używamy. Czy jest to polska, UTC, itp. Pamietajmy, ze strefa czasowa zmienia sie w zaleznosci od tego czy mamy czas letni, czy zimowy (zimowy to nasza nominalna strefa czasowa UTC+1, natomiast letnia, to UTC+2)-->.

### [Format Czasu Trwania (pzu:rest23:2025-duration-format)](#duration-format)

Format czasu trwania **MUSI** być zgodny ze standardem [ISO 8601](https://pl.wikipedia.org/wiki/ISO_8601), np.: `P3Y6M4DT12H30M5S` (trzy lata, sześć miesięcy, cztery dni, dwanaście godzin, trzydzieści minut i pięć sekund).

### [Format Przedziału Czasowego (pzu:rest24:2025-timeframe-format)](#timeframe-format)

Format przedziału czasowego **MUSI** być zgodny ze standardem [ISO 8601](https://pl.wikipedia.org/wiki/ISO_8601), np.: `2007-03-01T13:00:00Z/2008-05-11T15:30:00Z`.

### [Standardowe Znaczniki Czasowe (pzu:rest25:2025-timestamps)](#timestamps)

Gdy to możliwe, reprezentacja zasobu **POWINNA** zawierać standardowe znaczniki czasowe:

- `createdAt`
- `updatedAt`
- `finishedAt`

#### Przykład

```json
{
    "createdAt": "2017-01-01T12:00:00Z",
    "updatedAt": "2017-01-01T13:00:00Z",

    ...
}
```

### [Format Kodów Językowych (pzu:rest26:2025-language-codes)](#language-codes)

Kody językowe **MUSZĄ** być zgodne z [ISO 639](https://en.wikipedia.org/wiki/List_of_ISO_639-1_codes), np.: `pl` dla polskiego.

### [Format Kodów Krajów (pzu:rest27:2025-country-codes)](#country-codes)

Kody krajów **MUSZĄ** być zgodne z [ISO 3166-1 alpha-2](https://en.wikipedia.org/wiki/ISO_3166-1_alpha-2), np.: `PL` dla Polski.

### [Format Waluty (pzu:rest28:2025-currency-codes)](#currency-codes)

Kody walut **MUSZĄ** być zgodne z [ISO 4217](https://en.wikipedia.org/wiki/ISO_4217), np.: `PLN` dla polskiego złotego.

---

## [Stronicowanie (pzu:rest29:2025-pagination)](#pagination)

Zasób kolekcji **POWINIEN** udostępniać linki `first`, `last`, `next` i `prev` do nawigacji w obrębie kolekcji.

#### Przykład

Kolekcja zamówień z użyciem linków nawigacyjnych kolekcji oraz parametrów zapytania `offset` i `limit`:

```json
{
  "_links": {
    "self": { "href": "/orders?offset=100&limit=10" },
    "prev": { "href": "/orders?offset=90&limit=10" },
    "next": { "href": "/orders?offset=110&limit=10" },
    "first": { "href": "/orders?limit=10" },
    "last": { "href": "/orders?offset=900&limit=10" }
  },
  "totalCount": 910,
  "_embedded": {
    "order": [
      { ... },
      { ... },

      ... 
    ]
  }
}
```

---

## [Operacje Grupowe (Batch processing)](#batch-processing)

### [Przetwarzanie podobnych zasobów (pzu:rest30:2025-collections)](#collections)

Operacja, która musi przetwarzać kilka powiązanych zasobów w sposób wsadowy, **POWINNA** wykorzystywać zasób kolekcji z odpowiednią metodą HTTP. Podczas przetwarzania istniejących zasobów treść wiadomości żądania **MUSI** zawierać adresy URL odpowiednich zasobów, które są przetwarzane.

#### Przykład

Tworzenie wielu zamówień jednocześnie

```json
POST /orders
Content-Type: application/json

{
  "orders": [
    {
      "itemCount": 42
    },
    {
      "itemCount": 2
    }
  ]
}
```

Uaktulnianie wielu zamówień na raz

```json
PATCH /orders
Content-Type: application/json

{
  "orders": [
    {
      "_links": {
        "self": { "href": "/order/1"}
      },
      "itemCount": 42
    },
    {
      "_links": {
        "self": { "href": "/order/2"}
      },      
      "itemCount": 2
    }
  ]
}
```

### [Wyniki operacji grupowych (batch operations) (pzu:rest31:2025-batch-operations-results)](#batch-operations-results)

Każda operacja grupowa **MUSI** być atomowa i traktowana tak samo, jak każda inna operacja.

> Serwer musi implementować żądania zbiorcze jako atomowe. Jeśli żądanie dotyczy utworzenia dziesięciu adresów, serwer powinien utworzyć wszystkie dziesięć adresów przed zwróceniem kodu odpowiedzi oznaczającego sukces. Serwer nie powinien częściowo zatwierdzać zmian w przypadku niepowodzeń.

### [NIE UŻYWAJ "POST Tunneling" (pzu:rest31:2025-post-tunneling)](#post-tunneling)

Każde API **MUSI** unikać tunelowania wielu żądań HTTP w jednym żądaniu POST. Zamiast tego należy zapewnić dedykowany zasób aplikacyjny do przetwarzania żądań wsadowych.

### [Nieatomowe operacje grupowe (pzu:rest32:2025-non-atomic-batch-operations)](#non-atomic-batch-operations)

Operacje grupowe nieatomowe są zdecydowanie odradzane, ponieważ nakładają dodatkowe obciążenie i wprowadzają zamieszanie dla klienta. Trudno je konsumować, debugować, utrzymywać i rozwijać w dłuższym okresie czasu.

Zaleca się podzielenie operacji nieatomowej na kilka operacji atomowych. Koszt kilku dodatkowych wywołań zostanie zrekompensowany przez czystszy projekt, większą przejrzystość i łatwiejsze utrzymanie.

Jednakże, jeśli taka operacja musi zostać udostępniona, operacja wsadowa nieatomowa **MUSI** spełniać następujące wytyczne:7

- Operacja wsadowa nieatomowa **MUSI** zwrócić kod statusu sukcesu (np. `200 OK`) tylko wtedy, gdy każda z podoperacji zakończyła się powodzeniem.
- Jeśli którakolwiek z podoperacji zakończy się niepowodzeniem, cała operacja wsadowa nieatomowa **MUSI** zwrócić odpowiedni kod statusu `4xx` lub `5xx`.
- W przypadku błędu odpowiedź **MUSI** zawierać szczegóły problemu dla każdej podoperacji, która zakończyła się niepowodzeniem.
- Klient **MUSI** być świadomy, że operacja jest nieatomowa i że nawet jeśli operacja jako całość zakończyła się niepowodzeniem, niektóre podoperacje mogły zostać pomyślnie przetworzone. Taka informacja **MUSI** być zawarta w odpowiedzi API.

#### Przykład

Nieatomowe żądanie utworzenia czterech zamówień:

```json
POST /orders
Content-Type: application/json

{
  "orders": [
    {
      "itemCount": 42
    },
    {
      "itemCount": -100
    },        
    {
      "itemCount": 42
    },
    {
      "itemCount": 1.3232
    }
  ]
}
```

Odpowiedź błędu:
```json
HTTP/1.1 400 Bad Request
Content-Type: application/problem+json

{
  "type": "https://example.net/partial_operation_failure",
  "title": "Partial Failure",
  "detail": "Some orders couldn't be created, other orders were created.",

  "errors": [
    {
      "type": "https://example.net/invalid-params",
      "instance": "/orders/1",
      "title": "Invalid Parameter",
      "detail": "itemCount must be a positive integer",
      "status": 400
    },
    {
      "type": "https://example.net/invalid-params",
      "instance": "/orders/3",
      "title": "Invalid Parameter",
      "detail": "itemCount must be a positive integer",
      "status": 400
    }
  ],

  "processed": ...
}
```

Pole `processed` powinno zawierać wynik przetworzonych podoperacji tak, jakby zostały zwrócone w odpowiedzi `200 OK`.

---

## [Zapytania wyszukiwania (pzu:rest33:2025-filtering)](#filtering)

Operacja wyszukiwania (filtrowania) w zasobie kolekcji **POWINNA** być zdefiniowana jako bezpieczna, idempotentna i możliwa do buforowania, dlatego należy używać metody HTTP **GET**.  

Każdy parametr wyszukiwania **POWINIEN** być przekazywany w formie parametru zapytania (query parameter). W przypadku, gdy parametry wyszukiwania są wzajemnie wykluczające się lub wymagają obecności innego parametru, wyjaśnienie **MUSI** być częścią opisu operacji. 

Gdy jest to korzystne (np. jeden z parametrów filtrowania jest używany częściej niż inne), **POWINNO** zostać udostępnione osobne zasoby dla konkretnego zapytania. W takim przypadku kluczowy parametr wyszukiwania **MOŻE** być przekazany w formie zmiennej ścieżki.

<!-- Dodać co w przypadku dużej ilości query params (limit jest 1024 znakow w uri) -->

#### Przykład  

Kolekcja zamówień może być filtrowana według identyfikatora artykułu, który zawiera, lub według identyfikatora producenta artykułu. Te dwa parametry są wzajemnie wykluczające się i nie mogą być używane razem. Opis API dla takiego projektu powinien wyglądać następująco:  

```yaml
paths:
  /orders:
    x-summary: Collection of Orders

    get:
      summary: Retrieve or Search in the Collection of Orders
      description: | 

        This operation allows to retrieve a filtered list of orders based on multiple criteria:

        1. **Filter Orders by Article Id**
        2. **Filter Orders by Manufacturer Id**

      parameters:
        - name: article_id
          in: query
          description: | 
            Article Id. Denotes the id of an article that must be in the order.

            **Mutually exclusive** with `manufacturer_id`.

          required: false
          type: string
          x-example: article_id_1

        - name: manufacturer_id
          in: query
          description: |
            Manufacturer Id. Denotes an id of a manufacturer of an article that must be in the order.

            **Mutually exclusive** with `article_id`.

          required: false
          type: string
          x-example: manufacturer_id_1
```  

#### Przykład alternatywnego podejścia projektowego

Na podstawie powyższego przykładu udostępniamy filtrowanie zamówień według identyfikatora artykułu jako osobny zasób.  

```yaml
paths:
  /articles/{article_id}/orders:
    x-summary: Collection of Orders for given Article 

    get:
      summary: Retrieve the collection of Orders that contain given article.
```

---

## [Zmiany i Wersjonowanie](#changing-versioning)

### [Podstawowe zasady (pzu:rest34:2025-basic-versioning)](#basic-versioning)

> "Fundamentalną zasadą jest to, że nie możesz psuć istniejących klientów, ponieważ nie wiesz, co implementują, i nie masz nad nimi kontroli. Dlatego musisz zmienić niekompatybilną zmianę w taką, która jest kompatybilna."  
> – [Mark Nottingham](https://www.mnot.net/blog/2011/10/25/web_api_versioning_smackdown)

Żadna zmiana w API **NIE MOŻE** powodować problemów z działaniem istniejących klientów.

Zmiany dotyczące:

1. Identyfikatora zasobu (nazwa zasobu / URI), w tym parametrów zapytania i ich semantyki.
2. Metadanych zasobu (np. nagłówków HTTP).
3. Akcji dostępnych dla zasobu (np. dostępnych metod HTTP).
4. Relacji z innymi zasobami (np. linki).
5. Formatu reprezentacji (np. treści żądań i odpowiedzi HTTP).

**MUSZĄ** być zgodne z zasadami rozszerzania.

### [Zasady rozszerzania (pzu:general10:2025-rules-of-extension)](#rules-of-extending)

- **NIE MOŻNA** niczego usuwać (powiązane: [Zasada minimalnej powierzchni](https://en.wikipedia.org/wiki/YAGNI), [Zasada solidności](https://en.wikipedia.org/wiki/Robustness_principle))
- **NIE MOŻNA** zmieniać reguł przetwarzania
- **NIE MOŻNA** czynić opcjonalnych rzeczy wymaganymi
- Wszystko, co dodajesz, **MUSI** być opcjonalne (powiązane: [Zasada solidności](https://en.wikipedia.org/wiki/Robustness_principle))

### [Stabilność identyfikatorów (Brak wersjonowania URI) (pzu:rest35:2025-id-stability)](#id-stability)

Zmiana **NIE MOŻE** wpływać na istniejące identyfikatory zasobów (nazwy / URI). Ponadto identyfikator zasobu **NIE POWINIEN** zawierać wersji semantycznej w celu przekazania wersji zasobu lub jego formatu reprezentacji.

> "Powód tworzenia prawdziwego REST API to uzyskanie możliwości ewolucji... 'v1' to środkowy palec dla klientów API i sygnał, że jest to RPC/HTTP, a nie REST."  
> – Roy T. Fielding

#### Przykład

Dodanie nowej akcji do istniejącego zasobu o identyfikatorze `/greeting` NIE zmienia jego identyfikatora na `/v2/greeting` (lub `/greeting-with-new-action` itp.).

### [Zmiany niekompatybilne wstecz (pzu:rest36:2025-backwards-incompatibility)](#backwards-incompatibility)

Zmiana identyfikatora zasobu, metadanych zasobu, akcji zasobu lub relacji między zasobami, która **NIE MOŻE** być zgodna z zasadami rozszerzania, **MUSI** skutkować utworzeniem nowej wersji wariantu zasobu. Istniejący wariant zasobu **MUSI** zostać zachowany.

Zmiana formatu reprezentacji **NIE POWINNA** skutkować utworzeniem nowego wariantu zasobu.

#### Przykład  

Obecnie opcjonalny parametr zapytania `first` w istniejącym zasobie `/greeting?first=John&last=Appleseed` musi stać się wymagany. Ponieważ ta zmiana narusza trzecią zasadę rozszerzania i może powodować problemy z istniejącymi klientami, tworzony jest nowy wariant zasobu z innym URI: `/named-greeting?first=John&last=Appleseed`.


### [Zmiany formatu reprezentacji (pzu:rest37:2025-representation-format-change)](#representation-format-change)

Format reprezentacji to format serializacji (typ mediów) używany w treściach żądań i odpowiedzi HTTP, który zazwyczaj reprezentuje zasób lub jego część, ewentualnie z dodatkowymi kontrolkami hipermedialnymi.

Jeśli zmiana **NIE MOŻE** być zgodna z zasadami rozszerzania, typ mediów formatu reprezentacji **MUSI** zostać zmieniony. Jeśli typ mediów został zmieniony, poprzedni typ mediów **MUSI** być dostępny poprzez negocjację treści (content negotiation).

Jeśli typ mediów zawiera parametr wersji, parametr ten **POWINIEN** być zgodny z wersjonowaniem semantycznym.

#### Przykład

Typ mediów przed zmianą powodującą problemy:  

```text
application/vnd.example.resource+json; version=2
```

Typ mediów po zmianie powodującej problemy:  

```text
application/vnd.example.resource+json; version=3
```

> **UWAGA:** W przypadku ograniczeń technicznych związanych z wartościami nagłówków HTTP oddzielonymi średnikiem, wersja semantyczna **MOŻE** być zawarta w identyfikatorze typu mediów, np.:  

> ```
> application/vnd.example.resource.v2+json
> ```

> Jednak preferowane jest użycie informacji o wersji oddzielonej średnikiem.


### [Wersjonowanie opisu API (pzu:rest37:2025-api-description-versioning)](#api-description-versioning)

Opis API w formacie specyfikacji OpenAPI **MUSI** zawierać pole `version`. Pole `version` **MUSI** być zgodne z wersjonowaniem semantycznym:

- Zwiększaj wersję MAJOR przy wprowadzaniu niekompatybilnych zmian w API.
- Zwiększaj wersję MINOR przy dodawaniu funkcjonalności w sposób kompatybilny wstecz.
- Zwiększaj wersję PATCH przy poprawianiu błędów w sposób kompatybilny wstecz.

Wersja opisu API **POWINNA** być aktualizowana odpowiednio do zmian projektowych API.

#### Przykład

Poniższy opis API:  

```yaml
swagger: '2.0'
info:
  version: '2.1.3'
  title: 'Inventory API'
  description: 'Inventory service API'
```

Ma wersję MAJOR = 2, MINOR = 1 i PATCH = 3.

### Zalecana lektura
- [Evolving HTTP APIs](https://www.mnot.net/blog/2012/12/04/api-evolution)
