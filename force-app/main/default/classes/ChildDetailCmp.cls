/**
 * @description Lightning Component Apex that supports the ChildDetailCmp component
 *
 *-------------------------------------------------------------------------------------------------------------------
 * DEVELOPER                     DATE                   REASON
 *-------------------------------------------------------------------------------------------------------------------
 * c.hurd                       2025.09.24              created
 *******************************************************************************************************************
 */
public with sharing class ChildDetailCmp
{
    public static Map<String, String> fieldTypeToColumnType = new Map<String, String> {
            'BOOLEAN' => 'boolean',
            'CURRENCY' => 'currency',
            'DATE' => 'date-local',
            'DATETIME' => 'text',
            'DOUBLE' => 'number',
            'EMAIL' => 'email',
            'ID' => 'text',
            'INTEGER' => 'number',
            'MULTIPICKLIST' => 'text',
            'LONG' => 'number',
            'PERCENT' => 'percent',
            'PHONE' => 'phone',
            'PICKLIST' => 'text',
            'REFERENCE' => 'url',
            'STRING' => 'text',
            'TEXTAREA' => 'text',
            'URL' => 'text'
    };


    /**
     * @description : Gets the field columns for the child object
     * @param childObjectAPIName - the child object API name
     * @param fields - the fields to get
     * @return Map<String, Object> - the results
     */
    @AuraEnabled
    public static Map<String, Object> getMetadata(String childObjectAPIName, List<String> fields)
    {
        Set<String> queryFields = new Set<String> { 'Id' };
        Map<String, Map<String, Object>> lookupFieldsMap = new Map<String, Map<String, Object>>();
        Set<String> lookupObjects = new Set<String>();
        Map<String, Schema.DescribeFieldResult> fieldMap = getObjectFields(childObjectAPIName);
        List<Map<String, Object>> datatableColumns = new List<Map<String, Object>>();
        Map<String, Map<String, Object>> fieldMapColumns = new Map<String, Map<String, Object>>();

        for (String field : fields)
        {
            if (fieldMap.containsKey(field))
            {
                Map<String, Object> column = new Map<String, Object>();
                Schema.DescribeFieldResult fieldDescribe = fieldMap.get(field);
                String fieldType = fieldDescribe.getType().name();
                column.put('type', fieldTypeToColumnType.get(fieldType));
                column.put('label', fieldDescribe.getLabel());
                column.put('fieldName', field);
                column.put('fieldType', fieldType);
                queryFields.add(field);
                datatableColumns.add(column);
                fieldMapColumns.put(field, column);

                if (fieldDescribe.getType().name() == 'REFERENCE')
                {
                    String lookupObjectType = fieldDescribe.getReferenceTo()[0].getDescribe().getName();
                    lookupObjects.add(lookupObjectType);
                    lookupFieldsMap.put(field, column);
                    column.put('typeAttribute', new Map<String, Object> {
                            'label' => field + 'Name',
                            'target' => '_blank'
                    });
                    column.put('objectType', lookupObjectType);
                }
            }
        }

        if (lookupObjects.size() > 0)
        {
            Map<String, String> objectNameFields = getNameFields(lookupObjects);

            for (String field : lookupFieldsMap.keySet())
            {
                String lookupObject = fieldMap.get(field).getReferenceTo()[0].getDescribe().getName();
                String queryField = getRelationshipField(field) + '.' + objectNameFields.get(lookupObject);
                queryFields.add(queryField);
                fieldMapColumns.get(field).put('nameField', queryField);
            }
        }

        return new Map<String, Object> {
                'queryFields' => new List<String>(queryFields),
                'datatableColumns' => datatableColumns,
                'fieldMap' => fieldMapColumns
        };
    }


    @AuraEnabled
    public static SObject queryParent(String query, Id recordId)
    {
        List<SObject> records =  Database.query(query + ' WHERE Id = :recordId');

        if (!records.isEmpty())
        {
            return records[0];
        }
        else
        {
            return null;
        }
    }


    /**
     * @description : Gets the detail records for the child object
     * @param childObjectAPIName - the child object API name
     * @param parentRecordId - the parent record Id
     * @param parentFieldAPIName - the parent field API name on the child object
     * @param whereClause - the where clause to filter the records
     * @param orderBy - the order by clause
     * @param fields - the fields to query
     * @param fieldsMap - the fields map
     * @return List<Map<String, Object>> - the results
     */
    @AuraEnabled
    public static List<Map<String, Object>> getDetailRecords(
            String childObjectAPIName
            , Id parentRecordId
            , String parentFieldAPIName
            , String whereClause
            , String orderBy
            , List<String> fields
            , Map<String, Map<String, Object>> fieldsMap)
    {
        List<Map<String, Object>> results = new List<Map<String, Object>>();
        String query = 'SELECT ' + String.join(fields, ', ') + ' FROM ' + childObjectAPIName + ' WHERE ' + parentFieldAPIName + ' = :parentRecordId ';

        if (whereClause != null && whereClause != '')
        {
            query += ' AND ' + whereClause;
        }

        if (orderBy != null && orderBy != '')
        {
            query += ' ORDER BY ' + orderBy;
        }
        else {
            query += ' ORDER BY CreatedDate DESC NULLS LAST';
        }

        System.debug(query);

        for (SObject record : Database.query(query))
        {
            Map<String, Object> result = new Map<String, Object>();

            for (String field : fieldsMap.keySet())
            {
                Map<String, Object> fieldMap = fieldsMap.get(field);
                Object value = getFieldValue(record, (String) fieldMap.get('fieldName'));

                System.debug(fieldMap.get('fieldType'));

                if (value != null
                        && fieldMap.get('type')  == 'percent')
                {
                    value = (Decimal) value / 100;
                }
                else if (value != null
                        && value instanceof Datetime
                )
                {
                    value = ((Datetime) value).format('MM/dd/yyyy hh:mm a');
                }

                result.put(field, value);

                if (fieldMap.get('fieldType') == 'REFERENCE' && fieldMap.containsKey('nameField'))
                {
                    Object nameValue = getFieldValue(record, (String) fieldMap.get('nameField'));
                    result.put(field + 'Name', nameValue);
                }
            }

            results.add(result);
        }

        return results;
    }


    /**
     *   METHOD: getObjectFields
     *  @description : This method is used to get the objects fields
     *  @param childObjectAPIName : the child object API name
     *  @return Map<String, Schema.DescribeFieldResult> : the fields for the object
     */
    private static Map<String, Schema.DescribeFieldResult> getObjectFields(String childObjectAPIName)
    {
        DescribeSObjectResult sObjectResult = Schema.getGlobalDescribe().get(childObjectAPIName).getDescribe();
        Map<String, Schema.DescribeFieldResult> fieldMetadataMap = new Map<String, Schema.DescribeFieldResult>();

        for (Schema.SObjectField field : sObjectResult.fields.getMap().values())
        {
            Schema.DescribeFieldResult fieldResult = field.getDescribe();
            fieldMetadataMap.put(fieldResult.getName(), fieldResult);
        }

        return fieldMetadataMap;
    }

    /**
     * @description : This method is used to get the name fields for the given object types
     * @param objectTypes - Set<String> - the object types to get the metadata for
     * @return Map<String, String> - the object name fields
     */
    private static Map<String, String> getNameFields(Set<String> objectTypes)
    {
        Map<String, String> objectNameFields = new Map<String, String>();

        for(FieldDefinition fieldDefinition : [SELECT QualifiedApiName, Label, EntityDefinition.QualifiedApiName FROM FieldDefinition
        WHERE EntityDefinition.QualifiedApiName IN :objectTypes AND IsNameField = TRUE])
        {
            objectNameFields.put(fieldDefinition.EntityDefinition.QualifiedApiName, fieldDefinition.QualifiedApiName);
        }

        return objectNameFields;
    }

    /**
     *   METHOD: getRelationshipField
     *  @description : This method is used to get the relationship field for a given field
     *  @param field : The field to get the relationship field for
     *  @return String : The relationship field
     */
    private static String getRelationshipField(String field) {
        if (field.endsWith('__c')) {
            return field.replace('__c', '__r');
        }
        else if (field.endsWith('Id'))
        {
            return field.replace('Id', '');
        }
        else
        {
            return field;
        }
    }

    /**
     *   METHOD: getFieldValue
     *  @description : This method is used to get the value of a field on an SObject
     *  @param sobj : The SObject to get the field value from
     *  @param field : The field to get the value for
     *  @return Object : The value of the field
     */
    public static Object getFieldValue(SObject sobj, String field)
    {
        System.debug('field: ' + field);
        if (field != null)
        {
            if (field.contains('.'))
            {
                String[] fields = field.split('\\.');
                SObject currentObj = sobj.getSObject(fields[0]);

                for (Integer i = 1; i < fields.size(); ++i)
                {
                    String currentField = fields[i];
                    if (i < fields.size() - 1)
                    {
                        currentObj = currentObj.getSObject(currentField);
                    }
                    else
                    {
                        return currentObj?.get(currentField);
                    }
                }
            }
            else
            {
                return sobj.get(field);
            }
        }

        return null;
    }
}