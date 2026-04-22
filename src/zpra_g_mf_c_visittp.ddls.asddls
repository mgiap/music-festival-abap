@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Visit Projection'
@Metadata.allowExtensions: true
define view entity ZPRA_G_MF_C_VISITTP
  as projection on ZPRA_G_MF_R_VISIT
{
  key Uuid,
  ParentUuid,
  @ObjectModel.text.element: ['VisitorName']
  VisitorUuid,
  _Visitor.Name  as VisitorName,
  _Visitor.Email as VisitorEmail,
  ArtistIndicator,
  @ObjectModel.text.element: ['StatusText']
  Status,
  _VisitStatus.Description as StatusText,
  _MusicFestival.Title         as FestivalTitle,
  _MusicFestival.EventDateTime as FestivalEventDateTime,
  LocalLastChangedAt,
  _MusicFestival : redirected to parent ZPRA_G_MF_C_MUSICFESTIVALTP,
  _Visitor       : redirected to ZPRA_G_MF_C_VISITORTP,
  _VisitStatus
}
