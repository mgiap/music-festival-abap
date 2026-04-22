@AccessControl.authorizationCheck: #MANDATORY
@Metadata.allowExtensions: true
@ObjectModel.sapObjectNodeType.name: 'ZPRA_G_MF_A_VSTR000'
@EndUserText.label: '###GENERATED Core Data Service Entity'
define root view entity ZPRA_G_MF_R_VISITOR
  as select from zpra_g_mf_a_vstr as Visitors
  association [0..*] to ZPRA_G_MF_R_VISIT as _Visits
    on $projection.UUID = _Visits.VisitorUuid
{
  @ObjectModel.text.element: ['Name']
  key uuid as UUID,
  @Semantics.text: true
  name as Name,
  email as Email,
  @Semantics.user.createdBy: true
  created_by as CreatedBy,
  @Semantics.systemDateTime.createdAt: true
  created_at as CreatedAt,
  @Semantics.systemDateTime.lastChangedAt: true
  last_changed_at as LastChangedAt,
  @Semantics.user.lastChangedBy: true
  last_changed_by as LastChangedBy,
  @Semantics.systemDateTime.localInstanceLastChangedAt: true
  local_last_changed_at as LocalLastChangedAt,
  _Visits
}
