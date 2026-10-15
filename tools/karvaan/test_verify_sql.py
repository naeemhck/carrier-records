import unittest
from verify_sql import assertions, transaction


class VerificationContract(unittest.TestCase):
    def test_failed_or_missing_checks_cannot_pass(self):
        for value in ['1..1\nnot ok 1 - denied', '', 'BEGIN\nROLLBACK',
                      '1..2\nok 1 - one', '1..1\nok 1 - one\nBail out!']:
            with self.subTest(value=value), self.assertRaises(RuntimeError):
                assertions(value)

    def test_complete_plan_and_checks(self):
        self.assertEqual(assertions('BEGIN\n1..2\nok 1 - first\nok 2 - second\nROLLBACK'), 2)

    def test_harness_bootstrap_is_within_rollback(self):
        value = transaction('begin;\nselect plan(1);\nrollback;')
        self.assertLess(value.index('begin;'), value.index('create extension'))
        self.assertTrue(value.endswith('rollback;'))
        for source in ['select plan(1);', 'begin;\ncommit;', 'begin;begin;rollback;']:
            with self.assertRaises(RuntimeError): transaction(source)


if __name__ == '__main__': unittest.main()
