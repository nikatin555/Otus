# Наработки по доп.заданию

## Шаблоны для дополнительных заданий

### 3) Настройка аутентификации по SSH-ключам

#### `ssh-keys-setup.yml`
```yaml
---
- name: Configure SSH key authentication in FreeIPA
  hosts: ipa
  become: yes
  vars:
    ipa_admin_password: "SecurePassword123"

  tasks:
    - name: Install required packages
      dnf:
        name:
          - openssh-clients
        state: present

    - name: Generate SSH key pair for testuser
      openssh_keypair:
        path: /tmp/testuser_rsa
        type: rsa
        size: 2048
        state: present

    - name: Read public key
      slurp:
        src: /tmp/testuser_rsa.pub
      register: public_key

    - name: Add SSH public key to FreeIPA user
      shell: |
        echo "{{ ipa_admin_password }}" | kinit admin
        ipa user-mod testuser --ssh-pubkey="{{ public_key.content | b64decode | trim }}"
      args:
        executable: /bin/bash

    - name: Display public key info
      debug:
        msg: "SSH public key for testuser: {{ public_key.content | b64decode | trim }}"

    - name: Copy private key to Ansible control node
      fetch:
        src: /tmp/testuser_rsa
        dest: ./testuser_rsa
        flat: yes

    - name: Set permissions on private key
      file:
        path: ./testuser_rsa
        mode: '0600'
      delegate_to: localhost

- name: Configure SSH service on all hosts
  hosts: all
  become: yes

  tasks:
    - name: Ensure SSH key authentication is enabled
      lineinfile:
        path: /etc/ssh/sshd_config
        regexp: '^#?PubkeyAuthentication'
        line: 'PubkeyAuthentication yes'
        state: present

    - name: Ensure password authentication is enabled (for testing)
      lineinfile:
        path: /etc/ssh/sshd_config
        regexp: '^#?PasswordAuthentication'
        line: 'PasswordAuthentication yes'
        state: present

    - name: Ensure SSH service is enabled and running
      systemd:
        name: sshd
        state: restarted
        enabled: yes

- name: Test SSH key authentication
  hosts: localhost
  connection: local
  vars:
    test_private_key: "./testuser_rsa"

  tasks:
    - name: Test SSH connection with key to client1
      command: |
        ssh -i {{ test_private_key }} \
            -o StrictHostKeyChecking=no \
            -o UserKnownHostsFile=/dev/null \
            testuser@192.168.57.57 "whoami"
      register: ssh_test
      ignore_errors: yes

    - name: Display SSH test result
      debug:
        var: ssh_test.stdout

    - name: Verify SSH key works
      fail:
        msg: "SSH key authentication failed"
      when: ssh_test.rc != 0
```

#### `test-ssh-keys.yml`
```yaml
---
- name: Test SSH key authentication comprehensively
  hosts: localhost
  connection: local
  vars:
    private_key_path: "./testuser_rsa"

  tasks:
    - name: Check if private key exists
      stat:
        path: "{{ private_key_path }}"
      register: key_file

    - name: Generate key if missing
      openssh_keypair:
        path: "{{ private_key_path }}"
        type: rsa
        size: 2048
        state: present
      when: not key_file.stat.exists

    - name: Read public key content
      slurp:
        src: "{{ private_key_path }}.pub"
      register: pub_key
      when: key_file.stat.exists

    - name: Display public key for manual setup
      debug:
        msg: |
          To manually add SSH key to FreeIPA:
          ipa user-mod testuser --ssh-pubkey="{{ pub_key.content | b64decode | trim }}"

    - name: Test SSH to client1 with key
      command: |
        ssh -i {{ private_key_path }} \
            -o StrictHostKeyChecking=no \
            -o PasswordAuthentication=no \
            testuser@192.168.57.57 "echo 'SSH key auth successful'"
      register: test_client1
      ignore_errors: yes

    - name: Display client1 test result
      debug:
        var: test_client1

    - name: Test SSH to client2 with key
      command: |
        ssh -i {{ private_key_path }} \
            -o StrictHostKeyChecking=no \
            -o PasswordAuthentication=no \
            testuser@192.168.57.58 "echo 'SSH key auth successful'"
      register: test_client2
      ignore_errors: yes

    - name: Display client2 test result
      debug:
        var: test_client2
```

### 4) Настройка Firewall

#### `firewall-setup.yml`
```yaml
---
- name: Configure firewall on FreeIPA server
  hosts: ipa
  become: yes

  tasks:
    - name: Install firewalld
      dnf:
        name: firewalld
        state: present

    - name: Start and enable firewalld
      systemd:
        name: firewalld
        state: started
        enabled: yes

    - name: Add FreeIPA services to firewall
      firewalld:
        service: "{{ item }}"
        permanent: yes
        state: enabled
        immediate: yes
      loop:
        - dns
        - http
        - https
        - kerberos
        - ldap
        - ldaps
        - kpasswd

    - name: Add SSH service to firewall
      firewalld:
        service: ssh
        permanent: yes
        state: enabled
        immediate: yes

    - name: Add FreeIPA specific ports
      firewalld:
        port: "{{ item }}"
        permanent: yes
        state: enabled
        immediate: yes
      loop:
        - 8080/tcp  # IPA framework
        - 8443/tcp  # IPA CA
        - 7389/tcp  # Directory Server

    - name: Set default zone to public
      firewalld:
        zone: public
        state: enabled
        permanent: yes
        immediate: yes

    - name: Reload firewall rules
      command: firewall-cmd --reload

    - name: Display active firewall rules
      command: firewall-cmd --list-all
      register: firewall_status

    - name: Show firewall status
      debug:
        var: firewall_status.stdout

- name: Configure firewall on clients
  hosts: clients
  become: yes

  tasks:
    - name: Install firewalld
      dnf:
        name: firewalld
        state: present

    - name: Start and enable firewalld
      systemd:
        name: firewalld
        state: started
        enabled: yes

    - name: Add SSH service to firewall
      firewalld:
        service: ssh
        permanent: yes
        state: enabled
        immediate: yes

    - name: Allow FreeIPA server access
      firewalld:
        source: 192.168.57.56/32
        zone: public
        state: enabled
        permanent: yes
        immediate: yes

    - name: Set default zone to public
      firewalld:
        zone: public
        state: enabled
        permanent: yes
        immediate: yes

    - name: Reload firewall rules
      command: firewall-cmd --reload

    - name: Display active firewall rules
      command: firewall-cmd --list-all
      register: firewall_status

    - name: Show firewall status
      debug:
        var: firewall_status.stdout

- name: Test connectivity with firewall
  hosts: all
  become: yes

  tasks:
    - name: Test SSH connectivity
      wait_for:
        host: "{{ ansible_default_ipv4.address }}"
        port: 22
        timeout: 30
      delegate_to: localhost

    - name: Test FreeIPA services on server
      wait_for:
        host: "{{ ansible_host }}"
        port: "{{ item }}"
        timeout: 10
      loop:
        - 80
        - 443
        - 389
        - 636
      when: inventory_hostname == "ipa.otus.lan"
      delegate_to: localhost
```

#### `firewall-test.yml`
```yaml
---
- name: Comprehensive firewall testing
  hosts: localhost
  connection: local

  tasks:
    - name: Test FreeIPA web interface
      uri:
        url: https://ipa.otus.lan
        validate_certs: no
        status_code: 200
      register: web_test

    - name: Display web test result
      debug:
        var: web_test.status

    - name: Test SSH to FreeIPA server
      wait_for:
        host: 192.168.57.56
        port: 22
        timeout: 10
      register: ssh_ipa_test

    - name: Test SSH to client1
      wait_for:
        host: 192.168.57.57
        port: 22
        timeout: 10
      register: ssh_client1_test

    - name: Test SSH to client2
      wait_for:
        host: 192.168.57.58
        port: 22
        timeout: 10
      register: ssh_client2_test

    - name: Test FreeIPA LDAP service
      command: |
        nc -z -w 5 192.168.57.56 389
      register: ldap_test
      ignore_errors: yes

    - name: Test FreeIPA LDAPS service
      command: |
        nc -z -w 5 192.168.57.56 636
      register: ldaps_test
      ignore_errors: yes

    - name: Test FreeIPA Kerberos service
      command: |
        nc -z -w 5 192.168.57.56 88
      register: kerberos_test
      ignore_errors: yes

    - name: Display all test results
      debug:
        msg: |
          FreeIPA Web: {{ web_test.status }}
          SSH IPA: {{ ssh_ipa_test.elapsed }}s
          SSH Client1: {{ ssh_client1_test.elapsed }}s  
          SSH Client2: {{ ssh_client2_test.elapsed }}s
          LDAP: {{ ldap_test.rc == 0 }}
          LDAPS: {{ ldaps_test.rc == 0 }}
          Kerberos: {{ kerberos_test.rc == 0 }}
```

### Комбинированный playbook для всех заданий

#### `complete-setup.yml`
```yaml
---
- name: Complete FreeIPA setup with SSH keys and firewall
  hosts: all
  become: yes

  tasks:
    - name: Include basic setup
      include_tasks: basic-setup.yml

- name: FreeIPA server setup
  hosts: ipa
  become: yes

  tasks:
    - name: Include FreeIPA server setup
      include_tasks: ipa-server-setup.yml

- name: FreeIPA clients setup  
  hosts: clients
  become: yes

  tasks:
    - name: Include FreeIPA client setup
      include_tasks: ipa-client-setup.yml

- name: Firewall configuration
  hosts: all
  become: yes

  tasks:
    - name: Include firewall setup
      include_tasks: firewall-setup.yml

- name: SSH keys configuration
  hosts: ipa
  become: yes

  tasks:
    - name: Include SSH keys setup
      include_tasks: ssh-keys-setup.yml

- name: Final verification
  hosts: all
  become: yes

  tasks:
    - name: Include final tests
      include_tasks: final-verification.yml
```

### Инструкция по запуску:

```bash
# 1. Настройка SSH ключей
ansible-playbook -i inventory.ini ssh-keys-setup.yml

# 2. Настройка firewall
ansible-playbook -i inventory.ini firewall-setup.yml

# 3. Тестирование SSH ключей
ansible-playbook -i inventory.ini test-ssh-keys.yml

# 4. Тестирование firewall
ansible-playbook -i inventory.ini firewall-test.yml

# 5. Полная настройка (все задания)
ansible-playbook -i inventory.ini complete-setup.yml
```

### Проверка работы:

```bash
# Проверка SSH с ключом
ssh -i ./testuser_rsa testuser@192.168.57.57

# Проверка firewall правил
ansible all -i inventory.ini -a "firewall-cmd --list-all"

# Проверка FreeIPA сервисов
ansible ipa -i inventory.ini -a "ipactl status"
```

Эти шаблоны обеспечивают полную реализацию дополнительных заданий с проверкой работоспособности и тестированием.