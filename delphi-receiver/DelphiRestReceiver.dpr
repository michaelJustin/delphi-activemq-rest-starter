program DelphiRestReceiver;

// Receives one message from an ActiveMQ Classic queue through the REST API
// (MessageServlet) and maps its JSON body onto a TOrder with
// TJsonObject.ToSimpleObject.
//
// Usage: DelphiRestReceiver [-host localhost] [-port 8161] [-queue TEST.QUEUE]
//          [-user admin] [-password admin] [-timeout 10000] [-clientid delphi-receiver]

{$APPTYPE CONSOLE}

uses
  SysUtils,
  Classes,
  IdHTTP,
  IdURI,
  JsonDataObjects,
  OrderModel in 'OrderModel.pas';

const
  HTTP_NO_CONTENT = 204;

function GetOption(const Name, Default: string): string;
var
  I: Integer;
begin
  Result := Default;
  for I := 1 to ParamCount - 1 do
    if SameText(ParamStr(I), '-' + Name) then
    begin
      Result := ParamStr(I + 1);
      Exit;
    end;
end;

// Reads the response as UTF-8: the servlet writes UTF-8 for application/json
// but sends no charset parameter, so Indy's own decoding cannot be relied on.
function ReadUtf8(Stream: TMemoryStream): string;
var
  Utf8: UTF8String;
begin
  SetString(Utf8, PAnsiChar(Stream.Memory), Stream.Size);
  Result := UTF8ToString(Utf8);
end;

// The JSON written by XStream/Jettison (the jms-object-json format) wraps the
// object in a member named after the Java class, e.g.
// {"com.example.amqdemo.model.Order":{"id":1001,...}}. Return the inner object.
function UnwrapClassName(Root: TJsonObject): TJsonObject;
begin
  if (Root.Count = 1) and (Root.Items[0].Typ = jdtObject) then
    Result := Root.Items[0].ObjectValue
  else
    Result := Root;
end;

function ReceiveOrder(Order: TOrder): Boolean;
var
  HTTP: TIdHTTP;
  Response: TMemoryStream;
  URL, Body: string;
  Root: TJsonBaseObject;
begin
  Result := False;
  URL := Format('http://%s:%s/api/message/%s?type=queue&oneShot=true&readTimeout=%s&clientId=%s&json=true',
    [GetOption('host', 'localhost'), GetOption('port', '8161'),
     TIdURI.PathEncode(GetOption('queue', 'TEST.QUEUE')),
     GetOption('timeout', '10000'),
     TIdURI.ParamsEncode(GetOption('clientid', 'delphi-receiver'))]);

  HTTP := TIdHTTP.Create(nil);
  Response := TMemoryStream.Create;
  try
    HTTP.Request.BasicAuthentication := True;
    HTTP.Request.Username := GetOption('user', 'admin');
    HTTP.Request.Password := GetOption('password', 'admin');
    // the servlet holds the request open for up to readTimeout ms
    HTTP.ReadTimeout := StrToIntDef(GetOption('timeout', '10000'), 10000) + 5000;

    WriteLn('GET ', URL);
    HTTP.Get(URL, Response);

    // Indy does not raise on a 401 after a failed Basic authentication retry
    if HTTP.ResponseCode >= 300 then
      raise EIdHTTPProtocolException.CreateError(HTTP.ResponseCode,
        HTTP.ResponseText, ReadUtf8(Response));

    if (HTTP.ResponseCode = HTTP_NO_CONTENT) or (Response.Size = 0) then
    begin
      WriteLn('No message available.');
      Exit;
    end;

    Body := ReadUtf8(Response);
    WriteLn('Received JSON: ', Body);

    Root := TJsonObject.Parse(Body);
    try
      if not (Root is TJsonObject) then
        raise EJsonException.Create('Expected a JSON object');
      // Java field names are lowerCamelCase, the Delphi properties are not
      UnwrapClassName(TJsonObject(Root)).ToSimpleObject(Order, False);
    finally
      Root.Free;
    end;
    Result := True;
  finally
    Response.Free;
    HTTP.Free;
  end;
end;

var
  Order: TOrder;
begin
  ExitCode := 1;
  try
    Order := TOrder.Create;
    try
      if ReceiveOrder(Order) then
      begin
        WriteLn('Mapped object: ', Order.ToString);
        ExitCode := 0;
      end;
    finally
      Order.Free;
    end;
  except
    on E: EIdHTTPProtocolException do
      WriteLn('HTTP error ', E.ErrorCode, ': ', E.Message);
    on E: EJsonParserException do
      WriteLn('Invalid JSON: ', E.Message);
    on E: Exception do
      WriteLn(E.ClassName, ': ', E.Message);
  end;
end.
