import os
import unittest
import subprocess

class TestZeroTrustSuite(unittest.TestCase):
    def setUp(self):
        self.root = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))

    def test_core_files_exist(self):
        required = [
            "README.md",
            "Makefile",
            "SECURITY.md",
            ".gitattributes",
            "mtls/generate_mtls_certs.sh",
            "mtls/mtls_cert_manager.py",
            "firewall/nftables-zero-trust-default-deny.nft",
            "firewall/apply-firewall.sh",
            "spire/agent.conf",
            "spire/server.conf",
            "spire/register-workload.sh",
            "scripts/healthcheck.sh",
            "docs/architecture.svg"
        ]
        for f in required:
            p = os.path.join(self.root, f)
            self.assertTrue(os.path.exists(p), f"Required file '{f}' must exist")

    def test_nftables_rules_content(self):
        nft_file = os.path.join(self.root, "firewall", "nftables-zero-trust-default-deny.nft")
        with open(nft_file, "r", encoding="utf-8") as f:
            content = f.read()
        self.assertIn("policy drop;", content)
        self.assertIn("ct state { established, related } accept", content)
        self.assertIn("tcp dport 8443", content)

    def test_spire_agent_conf_content(self):
        conf_file = os.path.join(self.root, "spire", "agent.conf")
        with open(conf_file, "r", encoding="utf-8") as f:
            content = f.read()
        self.assertIn("trust_domain =", content)
        self.assertIn('server_port = "8081"', content)
        self.assertIn("WorkloadAttestor", content)

    def test_cert_manager_mock_mode(self):
        script = os.path.join(self.root, "mtls", "mtls_cert_manager.py")
        res = subprocess.run(["python", script, "--mock-test"], capture_output=True, text=True)
        self.assertEqual(res.returncode, 0)
        self.assertIn("spiffe://", res.stdout)

    def test_gitattributes_content(self):
        path = os.path.join(self.root, ".gitattributes")
        with open(path, "r", encoding="utf-8") as f:
            content = f.read()
        self.assertIn("* text=auto eol=lf", content)
        self.assertIn("Makefile linguist-vendored=true", content)

if __name__ == "__main__":
    unittest.main()
