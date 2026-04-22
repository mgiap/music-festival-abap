@Metadata.allowExtensions: true
@Metadata.ignorePropagatedAnnotations: true
@EndUserText: {
  label: '###GENERATED Core Data Service Entity'
}
@ObjectModel: {
  sapObjectNodeType.name: 'ZPRA_G_MF_A_VSTR000'
}
@AccessControl.authorizationCheck: #MANDATORY
define root view entity ZPRA_G_MF_C_VISITORTP
  provider contract transactional_query
  as projection on ZPRA_G_MF_R_VISITOR
{
  key UUID,
  Name,
  Email,
  @Semantics: {
    user.createdBy: true
  }
  CreatedBy,
  CreatedAt,
  @Semantics: {
    systemDateTime.lastChangedAt: true
  }
  LastChangedAt,
  @Semantics: {
    user.lastChangedBy: true
  }
  LastChangedBy,
  @Semantics: {
    systemDateTime.lastChangedAt: true
  }
  LocalLastChangedAt,
  _Visits : redirected to ZPRA_G_MF_C_VISITTP
}
