"""Regression for unordered balances; no change to accounting comparisons."""
import copy
import unittest
from t07_finance import canonical_ledger

class LedgerComparisonTests(unittest.TestCase):
    def setUp(self):
        self.before={'scope':'TRIP','complete':True,'label':'Synthetic',
            'balances':[{'party_id':'a','account_purpose':'CUSTOMER_RECEIVABLE','balance':'1.00'},
                        {'party_id':'b','account_purpose':'OWNER_PAYABLE','balance':'-1.00'}],
            'claims':[{'line_id':'a','remaining':'1.00','version':1},{'line_id':'b','remaining':'1.00','version':1}]}

    def test_balance_permutation_only(self):
        after=copy.deepcopy(self.before);after['balances'].reverse()
        self.assertNotEqual(after,self.before)
        self.assertEqual(canonical_ledger(after),canonical_ledger(self.before))
        self.assertEqual(self.before['balances'][0]['party_id'],'a')

    def test_reject_every_material_change(self):
        for change in ('amount','missing','extra','duplicate','claim_amount','claim_version','claim_order','scope','label','complete'):
            with self.subTest(change=change):
                after=copy.deepcopy(self.before)
                if change=='amount':after['balances'][0]['balance']='0.99'
                elif change=='missing':after['balances'].pop()
                elif change=='extra':after['balances'].append({'party_id':'c','balance':'0.00'})
                elif change=='duplicate':after['balances'].append(copy.deepcopy(after['balances'][0]))
                elif change=='claim_amount':after['claims'][0]['remaining']='0.99'
                elif change=='claim_version':after['claims'][0]['version']=2
                elif change=='claim_order':after['claims'].reverse()
                elif change=='scope':after['scope']='ALL'
                elif change=='label':after['label']='Changed'
                else:after['complete']=False
                self.assertNotEqual(canonical_ledger(after),canonical_ledger(self.before))

if __name__=='__main__':unittest.main()
