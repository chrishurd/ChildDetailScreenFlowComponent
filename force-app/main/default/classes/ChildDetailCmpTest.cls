/**
 * Created by chrishurd on 9/29/25.
 */

@IsTest
private class ChildDetailCmpTest
{
    @IsTest
    static void getMetadataTest()
    {
        Map<String, Object> metadata = ChildDetailCmp.getMetadata('Case', new List<String> {'AccountId', 'ContactId', 'Status', 'CreatedDate'});


        System.debug('metadata: ' + metadata.get('fieldMap'));
        Assert.areEqual(7, ((List<String>) metadata.get('queryFields')).size());
        Map<String, Object> fieldMap = (Map<String, Object>) metadata.get('fieldMap');
        Assert.areEqual('AccountId', ((Map<String, Object>) fieldMap.get('AccountId')).get('fieldName'));
        Assert.areEqual('Account.Name', ((Map<String, Object>) fieldMap.get('AccountId')).get('nameField'));

        Account account = new Account(Name='Test Account');
        insert account;

        Contact contact = new Contact(FirstName='Test', LastName='Contact', AccountId=account.Id);
        insert contact;

        Case caseRecord = new Case(AccountId=account.Id, ContactId=contact.Id, Status='New');
        insert caseRecord;

        List<Map<String, Object>> records = ChildDetailCmp.getDetailRecords('Case', account.Id, 'AccountId', 'CreatedDate != null', 'CaseNumber', (List<String>) metadata.get('queryFields'), (Map<String, Map<String, Object>>) metadata.get('fieldMap'));
        System.debug('records: ' + records);
        Assert.areEqual(1, records.size());
        Assert.areEqual(account.Id, records[0].get('AccountId'));
        Assert.areEqual(contact.Id, records[0].get('ContactId'));
        Assert.areEqual('Test Account', records[0].get('AccountIdName'));
        Assert.areEqual('Test Contact', records[0].get('ContactIdName'));
    }
}