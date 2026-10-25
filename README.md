# delphi-activemq-rest-starter

A minimal, working example of exchanging an object between Java and Delphi
through [Apache ActiveMQ Classic](https://activemq.apache.org/components/classic/):

* a **Java sender** (Maven) creates a JMS `ObjectMessage` holding an `Order` object,
* a client-side **`MessageTransformer`** turns the object into JSON on the way out,
  in the same format as ActiveMQ's `jms-object-json` transformation,
* a **Delphi receiver** (Indy `TIdHTTP`) consumes the message through the
  ActiveMQ **REST API** and maps the JSON onto a `TPersistent` descendant with
  [JsonDataObjects](https://github.com/ahausladen/JsonDataObjects)' `ToSimpleObject`.

```
 Java sender                       ActiveMQ Classic 6.3.2                 Delphi receiver
 ───────────                       ──────────────────────                 ───────────────
 ObjectMessage(Order)                                                     TIdHTTP GET
   │ MessageTransformer            queue TEST.QUEUE                       /api/message/TEST.QUEUE
   │ (XStream + Jettison,   ──►   (TextMessage, JSON)   ──►  REST 8161  ──► JSON
   ▼  jms-object-json format)                                               │ TJsonObject.Parse
 TextMessage ── OpenWire 61616 ──►                                          ▼ ToSimpleObject
                                                                          TOrder (TPersistent)
```

> [!WARNING]
> The ActiveMQ Classic REST API (`MessageServlet`) is **disabled by default** in
> ActiveMQ 6.x. Its configuration describes it as *deprecated, unmaintained,
> with multiple security related issues, primarily meant for demo purposes*,
> and it *will be removed entirely in a future release*. Use this project to
> learn and to prototype. Do not expose the REST API on an untrusted network.

## Why a client-side transformer?

ActiveMQ's `jms-object-json` transformation is a **STOMP** feature. The REST
API does not apply message transformations: for an `ObjectMessage` it only
returns `getObject().toString()`, and the broker would need the Java classes on
its class path to do even that.

So the Java sender does the conversion itself. `JsonObjectMessageTransformer`
implements [`org.apache.activemq.MessageTransformer`](https://activemq.apache.org/components/classic/documentation/maven/apidocs/org/apache/activemq/MessageTransformer.html)
and is registered on the connection factory. Application code still sends a
plain `ObjectMessage`. The transformer replaces it with a `TextMessage`
containing the object as JSON. The JSON is written with XStream and Jettison,
configured exactly like the broker's `jms-object-json` transformation, so
STOMP clients that expect that format can read these messages too.

Benefits:

* the broker stores plain JSON text,
* no model JAR on the broker class path, no `SERIALIZABLE_PACKAGES` setting,
* the broker never deserializes a Java object.

The message also gets a string property `transformation=jms-object-json`,
which the REST API returns as an HTTP response header.

## Prerequisites

| Component | Version | Notes |
|---|---|---|
| Delphi | 2009 or newer | Console application, Win32 |
| [Indy](https://github.com/IndySockets/Indy) | 10.6.3.15 | The Indy 10 version bundled with Delphi 2009 is too old, use a current one |
| [JsonDataObjects](https://github.com/ahausladen/JsonDataObjects) | current `master` | Not included in this repository |
| [ActiveMQ Classic](https://activemq.apache.org/components/classic/download/) | 6.3.2 | Local default installation |
| Java | 17 or newer | A JDK, not only a JRE, to build the sender |
| [Maven](https://maven.apache.org/) | 3.x | |

The Delphi project expects Indy and JsonDataObjects next to this repository's
folder:

```
<parent>\
  delphi-activemq-rest-starter\   (this repository)
  Indy\Lib\{Core,Protocols,System}
  JsonDataObjects\Source
```

If they live elsewhere, change `IndyLib` and `JsonDataObjectsSource` at the top
of `delphi-receiver/DelphiRestReceiver.dproj`, or set `INDY` and
`JSONDATAOBJECTS` before running `build.cmd`.

## Broker setup

1. Install ActiveMQ Classic 6.3.2 with its default configuration
   (OpenWire on port 61616, web console on port 8161, user `admin`/`admin`).
2. Enable the REST API. In `<ACTIVEMQ_HOME>/webapps/api/WEB-INF/web.xml`, the
   `MessageServlet` and its mapping are commented out. Uncomment them, or add
   this block next to the `jolokia-agent` servlet:

   ```xml
   <servlet>
       <servlet-name>MessageServlet</servlet-name>
       <servlet-class>org.apache.activemq.web.MessageServlet</servlet-class>
       <load-on-startup>1</load-on-startup>
       <async-supported>true</async-supported>
   </servlet>
   <servlet-mapping>
       <servlet-name>MessageServlet</servlet-name>
       <url-pattern>/message/*</url-pattern>
   </servlet-mapping>
   ```

3. Start (or restart) the broker:

   ```
   cd <ACTIVEMQ_HOME>\bin
   activemq start
   ```

   `data/activemq.log` now contains `Using @Deprecated Class org.apache.activemq.web.MessageServlet`.
4. Check that the web console at <http://localhost:8161/admin> works.

No other broker changes are needed.

## Build and run

### 1. Build and run the Java sender

```
cd java-sender
mvn package
java -jar target/java-sender-1.0.0-all.jar
```

(or `mvn compile exec:java`). Output:

```
Sent Order[id=1001, product=Würfel (6-sided), quantity=3, price=19.99, created=2026-10-25T09:39:01Z] to queue TEST.QUEUE at tcp://localhost:61616
```

The web console now shows one pending message in `TEST.QUEUE`. Its body is
the JSON text below.

### 2. Optional: look at the message with curl

```
curl -u admin:admin "http://localhost:8161/api/message/TEST.QUEUE?type=queue&oneShot=true&readTimeout=5000&clientId=curl&json=true"
```

```json
{"com.example.amqdemo.model.Order":{"id":1001,"product":"Würfel (6-sided)","quantity":3,"price":19.99,"created":"2026-10-25T09:39:01Z"}}
```

This consumes the message, so run the sender again before the next step.

### 3. Build and run the Delphi receiver

Open `delphi-receiver/DelphiRestReceiver.dproj` in Delphi and build it, or
build from the command line:

```
cd delphi-receiver
build.cmd
DelphiRestReceiver.exe
```

Output:

```
GET http://localhost:8161/api/message/TEST.QUEUE?type=queue&oneShot=true&readTimeout=10000&clientId=delphi-receiver&json=true
Received JSON: {"com.example.amqdemo.model.Order":{"id":1001,"product":"Würfel (6-sided)","quantity":3,"price":19.99,"created":"2026-10-25T09:39:01Z"}}
Mapped object: TOrder[Id=1001, Product=Würfel (6-sided), Quantity=3, Price=19.99, Created=2026-10-25T09:39:01Z]
```

The exit code is 0 when a message was received and mapped, and 1 otherwise.
When the queue is empty, the receiver waits up to the read timeout and then
prints `No message available.`

## How the Delphi side works

1. `TIdHTTP.Get` sends `GET /api/message/<queue>?type=queue&oneShot=true&readTimeout=<ms>&clientId=<id>&json=true`
   with HTTP Basic authentication.
   * `oneShot=true` closes the servlet's consumer after one message.
   * `readTimeout` is how long the servlet waits for a message.
   * `json=true` only sets the response `Content-Type` to `application/json`.
2. The response body is decoded as UTF-8. The servlet sends no `charset`
   parameter, so the program doesn't rely on Indy's decoding.
3. `TJsonObject.Parse` parses the body. The `jms-object-json` format wraps the
   object in a member named after the Java class, so the receiver unwraps the
   single inner object.
4. `ToSimpleObject(Order, False)` copies the JSON values into the published
   properties of `TOrder`. `False` makes the name match case-insensitive:
   Java `id` → Delphi `Id`.

## Keeping Java and Delphi in sync

| Java field (`Order`) | JSON | Delphi published property (`TOrder`) |
|---|---|---|
| `long id` | number | `Id: Int64` |
| `String product` | string | `Product: string` |
| `int quantity` | number | `Quantity: Integer` |
| `double price` | number | `Price: Double` |
| `String created` (ISO-8601) | string | `Created: string` |

Rules imposed by `ToSimpleObject`:

* Only **published** properties are filled. The class must have RTTI, which
  any `TPersistent` descendant has.
* Properties are matched **by name**, here case-insensitively. JSON members
  without a matching property are ignored. Properties without a matching
  member keep their value.
* Supported kinds: integer, `Int64`, float (`TDateTime` is parsed as an
  ISO-8601 date), string, enumeration, set and `Variant`. Nested objects and
  arrays are not mapped. Keep the Java class flat, or map nested parts
  yourself.
* Prefer `String` with ISO-8601 for dates in Java. XStream writes
  `java.util.Date` and `java.time` types in its own formats. Also avoid
  `BigDecimal`.

## Configuration

Java sender (system properties):

| Property | Default |
|---|---|
| `brokerUrl` | `tcp://localhost:61616` |
| `queue` | `TEST.QUEUE` |

Example: `java -Dqueue=MY.QUEUE -jar target/java-sender-1.0.0-all.jar`

Delphi receiver (command-line options):

| Option | Default |
|---|---|
| `-host` | `localhost` |
| `-port` | `8161` |
| `-queue` | `TEST.QUEUE` |
| `-user` | `admin` |
| `-password` | `admin` |
| `-timeout` | `10000` (ms the servlet waits for a message) |
| `-clientid` | `delphi-receiver` |

Example: `DelphiRestReceiver.exe -queue MY.QUEUE -timeout 2000`

## Troubleshooting

| Symptom | Cause / fix |
|---|---|
| `HTTP error 404` | The `MessageServlet` is not enabled (see [Broker setup](#broker-setup)), or the broker was not restarted after changing `web.xml`. |
| `HTTP error 401` | Wrong user or password. The web server authenticates against `conf/users.properties` / `conf/groups.properties` (JAAS realm `ActiveMQRealm`). The default is `admin`/`admin`. |
| `No message available.` | The queue is empty, or a REST consumer from an earlier request without `oneShot=true` still holds the message for its `clientId`. Use `oneShot=true`, or wait for the servlet's session to expire. |
| The body is `Order[id=...]` instead of JSON | The message was sent without the transformer, as a real `ObjectMessage`. The REST API then returns `toString()`. Register `JsonObjectMessageTransformer` on the connection factory. |
| `Invalid JSON: ...` | The body is not JSON. See the previous row. |
| `TOrder` properties stay empty or zero | A name mismatch between the Java field and the Delphi property, or the class-name wrapper was not unwrapped. Print the raw JSON and compare the names. |
| Indy compile errors (e.g. missing `hcPATCH`) or `IdCompilerDefines.inc` not found | The Indy bundled with Delphi 2009 is on the library path. Put Indy 10.6.3.15 first in the search path, and add `Core` and `System` to the include path. |
| `ü` is shown as `³`, `�` or similar | The console code page, not the data. Delphi 2009's `WriteLn` writes ANSI text, and the Windows console uses the OEM code page. Try `chcp 1252` first. The `string` value itself is correct. |

## Security notes

* The REST `MessageServlet` is deprecated and has known security issues.
  Enable it only on a development machine, and never expose port 8161
  publicly.
* Change the default `admin`/`admin` credentials on any broker that isn't a
  local test installation.
* JMS `ObjectMessage` relies on Java deserialization, which is a well-known
  attack surface. This project keeps the object out of the broker by sending
  JSON text. XStream is used only to *write* JSON, never to read it. If you
  consume real `ObjectMessage`s anywhere, restrict the trusted packages
  (`org.apache.activemq.SERIALIZABLE_PACKAGES`) to the minimum.

## Further reading

* ActiveMQ Classic REST API: <https://activemq.apache.org/components/classic/documentation/rest>
* ActiveMQ message transformation (`jms-object-json`): <https://activemq.apache.org/components/classic/documentation/message-transformation>
* `org.apache.activemq.MessageTransformer` Javadoc: <https://activemq.apache.org/components/classic/documentation/maven/apidocs/org/apache/activemq/MessageTransformer.html>
* JsonDataObjects: <https://github.com/ahausladen/JsonDataObjects>
* For full messaging from Delphi over STOMP (with transactions, durable
  subscriptions, and `ObjectMessage` exchange with broker-side
  transformation), see [Habari ActiveMQ Client](https://www.habarisoft.com/habari_activemq.html).

## License

[MIT](LICENSE)
