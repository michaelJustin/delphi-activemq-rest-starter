unit OrderModel;

// Delphi mirror of the Java class com.example.amqdemo.model.Order.
//
// TJsonObject.ToSimpleObject fills published properties by name, so every
// Java field has a published property with the same name here (the match is
// case-insensitive, see ReceiveOrder in DelphiRestReceiver.dpr).

interface

uses
  Classes;

type
  TOrder = class(TPersistent)
  private
    FId: Int64;
    FProduct: string;
    FQuantity: Integer;
    FPrice: Double;
    FCreated: string;
  public
    procedure Assign(Source: TPersistent); override;
    function ToString: string; override;
  published
    property Id: Int64 read FId write FId;
    property Product: string read FProduct write FProduct;
    property Quantity: Integer read FQuantity write FQuantity;
    property Price: Double read FPrice write FPrice;
    property Created: string read FCreated write FCreated; // ISO-8601
  end;

implementation

uses
  SysUtils;

{ TOrder }

procedure TOrder.Assign(Source: TPersistent);
begin
  if Source is TOrder then
  begin
    FId := TOrder(Source).Id;
    FProduct := TOrder(Source).Product;
    FQuantity := TOrder(Source).Quantity;
    FPrice := TOrder(Source).Price;
    FCreated := TOrder(Source).Created;
  end
  else
    inherited Assign(Source);
end;

function TOrder.ToString: string;
var
  FormatSettings: TFormatSettings;
begin
  GetLocaleFormatSettings(0, FormatSettings);
  FormatSettings.DecimalSeparator := '.';
  Result := Format('TOrder[Id=%d, Product=%s, Quantity=%d, Price=%.2f, Created=%s]',
    [FId, FProduct, FQuantity, FPrice, FCreated], FormatSettings);
end;

end.
