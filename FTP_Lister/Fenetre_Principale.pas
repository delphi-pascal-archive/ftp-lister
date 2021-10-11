{
  FTP Lister version 1.0.0
  Octobre 2008
  Titi From Fr@nce (=John Dogget)
}
unit Fenetre_Principale;

interface

uses
  Windows, Forms, SysUtils, StrUtils,
  Dialogs, XPMan, ExtCtrls, Mask, StdCtrls, Buttons, ComCtrls,
  IdFTP, Controls, Classes, IdComponent, IdTCPConnection,
  IdTCPClient, Menus, ImgList, IdBaseComponent;

type TInfoFichier=record
  TypeFichier:char;
  Permissions:string;
  NbLiens:integer;
  Proprietaire:string;
  Groupe:string;
  Taille:int64;
  Date:string;
  Nom:string;
end;

type
  TForm1 = class(TForm)
    GroupBox1: TGroupBox;
    Panel1: TPanel;
    Panel2: TPanel;
    Panel3: TPanel;
    Panel4: TPanel;
    Edt_Serveur: TEdit;
    Edt_Port: TEdit;
    Edt_Utilisateur: TEdit;
    MaskEdt_MDP: TMaskEdit;
    XPManifest1: TXPManifest;
    BitBtn_ConnecterLister: TBitBtn;
    GroupBox2: TGroupBox;
    Memo_Log: TMemo;
    GroupBox3: TGroupBox;
    IdFTP: TIdFTP;
    TreeVw_Arborescence: TTreeView;
    Popup_DetailsFichiers: TPopupMenu;
    Chercherunfichier1: TMenuItem;
    GroupBox5: TGroupBox;
    ListVw_DetailsFichiers: TListView;
    ImgLst_TreeView: TImageList;
    Exporterlaliste1: TMenuItem;
    OpenDialog: TOpenDialog;
    procedure BitBtn_ConnecterListerClick(Sender: TObject);
    procedure IdFTPStatus(ASender: TObject; const AStatus: TIdStatus;
      const AStatusText: String);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure ListerDossierFTP(Dossier:string);
    function IsDossierFTP(ChaineServeur:string):boolean;
    function ConvertirTaille(TailleEnOctets:int64):string;
    function ExtraireInfoFichier(ChaineServeur:string):TInfoFichier;
    procedure Chercherunfichier1Click(Sender: TObject);
    procedure Exporterlaliste1Click(Sender: TObject);

  private
    { Déclarations privées }
  public
    { Déclarations publiques }
  end;

var
  Form1: TForm1;
  NbFichiers,NbDossiers:Cardinal;
  VolumeFichiers:int64;
  PlusGrandNom:byte;

implementation

{$R *.dfm}

procedure TForm1.BitBtn_ConnecterListerClick(Sender: TObject);
begin
  NbFichiers:=0;
  NbDossiers:=0;
  Memo_Log.Clear;
  ListVw_DetailsFichiers.Clear;
  // Effacement du treeview à faire ici
  // On remplie les parametres de connexion au serveur
  IdFTP.Host:=Edt_Serveur.Text;
  IdFTP.Port:=StrToInt(Edt_Port.Text);
  IdFTP.Username:=Edt_Utilisateur.Text;
  IdFTP.Password:=MaskEdt_MDP.Text;
  // On se connecte au serveur
  IdFTP.Connect();
  BitBtn_ConnecterLister.Enabled:=False;
  // On commence à explorer depuis la racine du serveur
  ListerDossierFTP('');
  // L'exploration est terminée, on se déconnecte
  IdFTP.Disconnect;
  BitBtn_ConnecterLister.Enabled:=True;
  MessageDlg('Exploration terminated!'+#13+#13+
             'Directories count: '+IntToStr(NbDossiers)+#13+
             'File count: '+IntToStr(NbFichiers)+#13+
             'Total size: '+ConvertirTaille(VolumeFichiers), mtInformation,[mbOk],0);
end;

procedure TForm1.IdFTPStatus(ASender: TObject; const AStatus: TIdStatus;
  const AStatusText: String);
begin
  // On affiche le déroulement des operations
  Memo_Log.Lines.Add(AStatusText);
end;

procedure TForm1.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
  // Déconnexion au cas où elle n'est pas faîte
  if IdFTP.Connected then
    IdFTP.Disconnect;
end;

procedure TForm1.ListerDossierFTP(Dossier:string);
var
  IndexResultat:integer;
  Liste:TStringList;
  InFoFichier:TInfoFichier;
begin
  // Liste va recevoir les réponses du serveur à la commande LIST
  Liste:=TStringList.Create;
  // On change de dossier pour se placer dans le dossier à explorer
  if Dossier<>'' then
    IdFTP.ChangeDir(Dossier);
  Memo_Log.Lines.Add('');
  Memo_Log.Lines.Add('Lecture du contenu du dossier '+Dossier);
  // On explore le dossier
  IdFTP.List(Liste);
  // Pour chaque élément présent dans ce dossier ...
  for IndexResultat:=0 to (Liste.Count-1) do
  begin
    // On transforme la réponse du serveur pour la rendre utilisable
    InfoFichier:=ExtraireInfoFichier(Liste[IndexResultat]);
    // On ajoute l'entrée dans le listview
    ListVw_DetailsFichiers.Items.Add.Caption:=InfoFichier.Nom;
    ListVw_DetailsFichiers.Items[ListVw_DetailsFichiers.Items.Count-1].SubItems.Add(InfoFichier.Permissions);
    ListVw_DetailsFichiers.Items[ListVw_DetailsFichiers.Items.Count-1].SubItems.Add(InfoFichier.Proprietaire);
    ListVw_DetailsFichiers.Items[ListVw_DetailsFichiers.Items.Count-1].SubItems.Add(InfoFichier.Groupe);
    ListVw_DetailsFichiers.Items[ListVw_DetailsFichiers.Items.Count-1].SubItems.Add(InfoFichier.Date);
    ListVw_DetailsFichiers.Items[ListVw_DetailsFichiers.Items.Count-1].SubItems.Add(ConvertirTaille(InfoFichier.Taille));
    // On rends le derbier élément ajouté visible
    ListVw_DetailsFichiers.Items[ListVw_DetailsFichiers.Items.Count-1].MakeVisible(False);
    // Au passage on note la longueur du nom, ça sera utile lors de l'exportation
    if Length(InfoFichier.Nom)>PlusGrandNom then
      PlusGrandNom:=Length(InfoFichier.Nom);
    // Pour laisser Windows souffler :p
    Application.ProcessMessages;
    if IsDossierFTP(Liste[IndexResultat][1]) then
    begin
      // L'élement que je viens de trouver est un dossier
      // Je l'ajoute au treeview avec l'icône d'un dossier
      if TreeVw_Arborescence.Selected=nil then
        TreeVw_Arborescence.Selected:=TreeVw_Arborescence.Items.Add(nil,InfoFichier.Nom)
      else
        TreeVw_Arborescence.Selected:=TreeVw_Arborescence.Items.AddChild(TreeVw_Arborescence.Selected,InfoFichier.Nom);
      TreeVw_Arborescence.Selected.ImageIndex:=0;
      Inc(NbDossiers);
      // Je relance recursivement une nouvelle recherche dans ce dossier
      ListerDossierFTP(Dossier+'/'+InfoFichier.Nom);
    end
    else
    begin
      // L'élement que je viens de trouver est un fichier
      // je l'ajoute au treeview avec l'icône d'un fichier
      TreeVw_Arborescence.Items.AddChild(TreeVw_Arborescence.Selected,InfoFichier.Nom).ImageIndex:=1;
      Inc(NbFichiers);
      VolumeFichiers:=VolumeFichiers+InfoFichier.Taille;
    end;
  end;
  // Je remonte d'un niveau dans l'arborescence du treeview si possible
  if TreeVw_Arborescence.Selected<>nil then
    TreeVw_Arborescence.Selected:=TreeVw_Arborescence.Selected.Parent;
  // Je libère la liste
  Liste.Free;
end;

function TForm1.IsDossierFTP(ChaineServeur:string):boolean;
begin
  // Test pour savoir si un élément de l'arborescence est un dossier
  if ChaineServeur[1]='d' then
    Result:=True
  else
    Result:=False;
end;

// Conversion des tailles en unités usuelles
function TForm1.ConvertirTaille(TailleEnOctets:int64):string;
const
  UnKiloOctet=1024;
  UnMegaOctet=1048576;
  UnGigaOctet=1073741824;
  UnTeraOctet=1099511627776;
begin
  if TailleEnOctets>UnTeraOctet then
  begin
    Result:=Format('%.3f To',[TailleEnOctets/UnTeraOctet]);
    exit;
  end;
  if TailleEnOctets>UnGigaOctet then
  begin
    Result:=Format('%.3f Go',[TailleEnOctets/UnGigaOctet]);
    exit;
  end;
  if TailleEnOctets>UnMegaOctet then
  begin
    Result:=Format('%.3f Mo',[TailleEnOctets/UnMegaOctet]);
    exit;
  end;
  if TailleEnOctets>UnKiloOctet then
  begin
    Result:=Format('%.3f Ko',[TailleEnOctets/UnKiloOctet]);
    exit;
  end;
  Result:=IntToStr(TailleEnOctets)+' Octets';
end;

// Extrait de la réponse du serveur les infos concernant un fichier
// cf fichier joinds pour les explications
function TForm1.ExtraireInfoFichier(ChaineServeur:string):TInfoFichier;
var
  InfoFichier:TInfoFichier;
  ChaineTemp:string;
  IndexChaine:byte;
begin
  ChaineTemp:=ChaineServeur;
  InfoFichier.TypeFichier:=ChaineTemp[1];
  Delete(ChaineTemp,1,1);
  InfoFichier.Permissions:=LeftStr(ChaineTemp,9);
  Delete(ChaineTemp,1,9);
  ChaineTemp:=TrimLeft(ChaineTemp);
  For IndexChaine:=1 to Length(ChaineTemp) do
    if ChaineTemp[IndexChaine]=' ' then
      break;
  InfoFichier.NbLiens:=StrToInt(LeftStr(ChaineTemp,IndexChaine-1));
  Delete(ChaineTemp,1,Length(LeftStr(ChaineTemp,IndexChaine-1)));
  ChaineTemp:=TrimLeft(ChaineTemp);
  For IndexChaine:=1 to Length(ChaineTemp) do
    if ChaineTemp[IndexChaine]=' ' then
      break;
  InfoFichier.Proprietaire:=LeftStr(ChaineTemp,IndexChaine-1);
  Delete(ChaineTemp,1,Length(InfoFichier.Proprietaire));
  ChaineTemp:=TrimLeft(ChaineTemp);
  For IndexChaine:=1 to Length(ChaineTemp) do
    if ChaineTemp[IndexChaine]=' ' then
      break;
  InfoFichier.Groupe:=LeftStr(ChaineTemp,IndexChaine-1);
  Delete(ChaineTemp,1,Length(InfoFichier.Groupe));
  ChaineTemp:=TrimLeft(ChaineTemp);
  For IndexChaine:=1 to Length(ChaineTemp) do
    if ChaineTemp[IndexChaine]=' ' then
      break;
  InfoFichier.Taille:=StrToInt64(LeftStr(ChaineTemp,IndexChaine-1));
  Delete(ChaineTemp,1,Length(LeftStr(ChaineTemp,IndexChaine-1)));
  ChaineTemp:=TrimLeft(ChaineTemp);
  InfoFichier.Date:=LeftStr(ChaineTemp,12);
  Delete(ChaineTemp,1,Length(InfoFichier.Date));
  ChaineTemp:=TrimLeft(ChaineTemp);
  InfoFichier.Nom:=ChaineTemp;
  Result:=InfoFichier;
end;

// Chercher un fichier dans l'arborescence
procedure TForm1.Chercherunfichier1Click(Sender: TObject);
var
  FichierAChercher:string;
  IndexListe:integer;
begin
  FichierAChercher:=InputBox('Chercher un fichier','Entrez le nom du fichier à chercher','');
  for IndexListe:=0 to ListVw_DetailsFichiers.Items.Count do
  begin
    if AnsiCompareText(ListVw_DetailsFichiers.Items[IndexListe].Caption,FichierAChercher)=0 then
    begin
       // Fichier trouvé, on le selectionne dans le listview et on le rend visible
       ListVw_DetailsFichiers.Selected:=ListVw_DetailsFichiers.Items[IndexListe];
       ListVw_DetailsFichiers.Selected.MakeVisible(False);
       break;
    end;
  end;
end;

// Exportation de la liste des fichiers dans un fichier texte
procedure TForm1.Exporterlaliste1Click(Sender: TObject);
var
  Fichier:TextFile;
  IndexListe:integer;
  ChaineTaille:string;
begin
  OpenDialog.Execute;
  AssignFile(Fichier,OpenDialog.FileName);
  Rewrite(Fichier);
  WriteLn(Fichier,' Nom'+DupeString(' ',PlusGrandNom-2)+'| Permissions  | Proprietaire | Groupe       | Date         | Taille');
  WriteLn(Fichier,DupeString('-',PlusGrandNom+2)+'+'+DupeString('-',14)+'+'+DupeString('-',14)+'+'+DupeString('-',14)+'+'+DupeString('-',14)+'+'+DupeString('-',14));
  for IndexListe:=0 to (ListVw_DetailsFichiers.Items.Count-1) do
  begin
    if ListVw_DetailsFichiers.Items[IndexListe].SubItems[4]='4,000 Ko' then
      ChaineTaille:='Dossier'
    else
      ChaineTaille:=ListVw_DetailsFichiers.Items[IndexListe].SubItems[4];
    WriteLn(Fichier,' '+ListVw_DetailsFichiers.Items[IndexListe].Caption+DupeString(' ',PlusGrandNom-Length(ListVw_DetailsFichiers.Items[IndexListe].Caption)+1)+'| '+
    ListVw_DetailsFichiers.Items[IndexListe].SubItems[0]+DupeString(' ',4)+'| '+
    ListVw_DetailsFichiers.Items[IndexListe].SubItems[1]+DupeString(' ',13-Length(ListVw_DetailsFichiers.Items[IndexListe].SubItems[1]))+'| '+
    ListVw_DetailsFichiers.Items[IndexListe].SubItems[2]+DupeString(' ',13-Length(ListVw_DetailsFichiers.Items[IndexListe].SubItems[2]))+'| '+
    ListVw_DetailsFichiers.Items[IndexListe].SubItems[3]+DupeString(' ',1)+'| '+ChaineTaille);
  end;
  CloseFile(Fichier);
  MessageDlg('Exportation terminée !',mtInformation,[mbOk],0);
end;

end.
