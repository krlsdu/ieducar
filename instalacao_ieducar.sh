  pgvm_home=/home/$USER/.pgvm
  pgvm_logs=${pgvm_home}/logs
  pgvm_clusters=${pgvm_home}/clusters
  pgvm_environments=${pgvm_home}/environments

  export pgvm_home pgvm_logs pgvm_environments pgvm_clusters
  export PATH=${pgvm_home}/bin:$PATH
  export PATH=${pgvm_environments}/current/bin:$PATH



# @author: Lucas D'Ávila (Portabilis)

echo -e "\n\n** Atualizando apt-get"
sudo apt-get update -y

echo -e "\n\n** Instalando git"
sudo apt-get install -y git-core

echo -e "\n\n** Instalando apache e mod_rewrite"
sudo apt-get install -y apache2
sudo a2enmod rewrite
sudo service apache2 restart

echo -e "\n\n** Instalando php5"
sudo apt-get install -y libapache2-mod-php5 php5-pgsql

echo -e "\n\n** Instalando pear"
sudo apt-get install -y php-pear
sudo service apache2 restart

echo -e "\n\n** Instalando pgvm"
sudo apt-get install -y curl
curl -s -L https://raw.github.com/krlsdu/pgvm/master/bin/pgvm-self-install | bash
----------------------------------------------------------------------------------------------------


# @author: Lucas D'Ávila (Portabilis)
echo -e "\n\n** Instalando dependências para instalação postgresql"
sudo apt-get install -y libreadline6 libreadline6-dev make gcc zlib1g-dev

echo -e "\n\n** Instalando postgres 8.2 via pgvm"
pgvm install 8.2

echo -e "\n\n** Criando cluster main"
pgvm use 8.2.23
pgvm cluster create main
pgvm cluster start main

echo -e "\n\n** Adicionando usuário ieducar"
~/.pgvm/environments/8.2.23/bin/createuser --superuser ieducar -p 5433

echo -e "\n\n** Baixando dump banco de dados"
sudo apt-get install -y wget
rm -f ieducar.backup.gz
rm -f ieducar.backup
wget https://s3-us-west-2.amazonaws.com/portabilis2/public/ieducar/ieducar.backup.gz
gunzip ieducar.backup.gz

echo -e "\n\n** Destruindo banco de dados caso exista"
~/.pgvm/environments/8.2.23/bin/dropdb ieducar -p 5433

echo -e "\n\n** Restaurando dump do banco de dados"
~/.pgvm/environments/8.2.23/bin/createdb ieducar -E latin1 -p 5433
~/.pgvm/environments/8.2.23/bin/pg_restore -d ieducar -p 5433 -U ieducar --no-owner ieducar.backup

echo -e "\n\n** Definindo search_path"
~/.pgvm/environments/8.2.23/bin/psql -d ieducar -p 5433 -c 'ALTER DATABASE ieducar SET search_path = "$user", public, portal, cadastro, acesso, alimentos, consistenciacao, historico, pmiacoes, pmicontrolesis, pmidrh, pmieducar, pmiotopic, urbano, modules;'



----------------------------------------------------------------------------------------------------

echo -e "\n\n ** clonando repositorio ieducar"

git clone https://github.com/portabilis/ieducar.git ~/ieducar


----------------------------------------------------------------------------------------------------


# este arquivo deve ser usado para instalar as dependencias do i-educar,
#
# para instalar o pear no ubuntu: sudo apt-get install php-pear
# ou para atualizar uma instalação já existente: sudo pear upgrade pear

echo -e "\n\n** Instalando dependencias i-Educar"

sudo pear install XML_RPC2

# mailer
sudo pear install Mail
sudo pear install Net_SMTP

# recaptcha
sudo pear install Services_ReCaptcha

sudo service apache2 restart


----------------------------------------------------------------------------------------------------


# @autor: Lucas D'Ávila (Portabilis)

echo -e "\n\n** Configurando virtual host"
sudo apt-get install -y rpl

sudo rm -f /etc/apache2/sites-enabled/ieducar
sudo rm -f /etc/apache2/sites-available/ieducar
sudo wget https://s3-us-west-2.amazonaws.com/portabilis2/public/ieducar/apache/sites-available/ieducar -P /etc/apache2/sites-available/
sudo rpl "/home/portabilis" "/home/$USER" /etc/apache2/sites-available/ieducar

sudo a2dissite 000-default
sudo a2ensite ieducar
sudo service apache2 restart

if ! grep -q ieducar.local /etc/hosts; then 
  echo -e "\n\n** Adicionando host para ieducar.local"
  echo "127.0.0.1   ieducar.local" | sudo tee -a /etc/hosts
fi

----------------------------------------------------------------------------------------------------


echo -e "\n** Rodando migração mytdt/1_adiciona_campo_secao_em_area_conhecimento.sql"

~/.pgvm/environments/8.2.23/bin/psql -d ieducar -p 5433 -c "
ALTER TABLE modules.area_conhecimento ADD COLUMN secao character varying(50);"

echo -e "\n** Rodando migração 53_cria_campo_observacao_matricula.sql"
 
~/.pgvm/environments/8.2.23/bin/psql -d ieducar -p 5433 -c "ALTER TABLE pmieducar.matricula ADD COLUMN observacao character varying(300);
UPDATE pmieducar.matricula set observacao = 'Não Informado' where aprovado= 6;"
 
echo -e "\n** Rodando migração 54_retira_obrigatoriedade_de_campos_hora_em_escola_serie.sql"
 
~/.pgvm/environments/8.2.23/bin/psql -d ieducar -p 5433 -c "
ALTER TABLE pmieducar.escola_serie ALTER COLUMN hora_inicial drop not null;
ALTER TABLE pmieducar.escola_serie ALTER COLUMN hora_final drop not null;
ALTER TABLE pmieducar.escola_serie ALTER COLUMN hora_inicio_intervalo drop not null;
ALTER TABLE pmieducar.escola_serie ALTER COLUMN hora_fim_intervalo drop not null;"
 
echo -e "\n** Rodando migração 55_controle_de_empresas_transporte_escolar.sql"
 
~/.pgvm/environments/8.2.23/bin/psql -d ieducar -p 5433 -c "
CREATE SEQUENCE modules.empresa_transporte_escolar_seq
INCREMENT 1
MINVALUE 1
MAXVALUE 9223372036854775807
START 1
CACHE 1;
ALTER TABLE modules.empresa_transporte_escolar_seq
OWNER TO ieducar;

CREATE TABLE modules.empresa_transporte_escolar
(
cod_empresa_transporte_escolar integer NOT NULL DEFAULT nextval('modules.empresa_transporte_escolar_seq'::regclass),
ref_idpes integer NOT NULL,
ref_resp_idpes integer NOT NULL,
observacao character varying(255),
CONSTRAINT empresa_transporte_escolar_cod_empresa_transporte_escolar_pkey PRIMARY KEY (cod_empresa_transporte_escolar ),
CONSTRAINT empresa_transporte_escolar_ref_idpes_fkey FOREIGN KEY (ref_idpes)
REFERENCES cadastro.juridica (idpes) MATCH SIMPLE,
CONSTRAINT empresa_transporte_escolar_ref_resp_idpes_fkey FOREIGN KEY (ref_resp_idpes)
REFERENCES cadastro.fisica (idpes) MATCH SIMPLE
ON UPDATE RESTRICT ON DELETE RESTRICT
)
WITH (
OIDS=TRUE
);

CREATE SEQUENCE modules.motorista_seq
INCREMENT 1
MINVALUE 1
MAXVALUE 9223372036854775807
START 1
CACHE 1;
ALTER TABLE modules.motorista_seq
OWNER TO ieducar;


CREATE TABLE modules.motorista
(
cod_motorista integer NOT NULL DEFAULT nextval('modules.motorista_seq'::regclass),
ref_idpes integer NOT NULL,
cnh character varying(15) NOT NULL,
tipo_cnh character varying(2) NOT NULL,
dt_habilitacao date,
vencimento_cnh date,
ref_cod_empresa_transporte_escolar integer NOT NULL,
observacao character varying(255),
CONSTRAINT motorista_pkey PRIMARY KEY (cod_motorista),
CONSTRAINT motorista_ref_idpes_fkey FOREIGN KEY (ref_idpes)
REFERENCES cadastro.fisica (idpes) MATCH SIMPLE
ON UPDATE RESTRICT ON DELETE RESTRICT,
CONSTRAINT motorista_ref_cod_empresa_transporte_escolar_fkey FOREIGN KEY (ref_cod_empresa_transporte_escolar)
REFERENCES modules.empresa_transporte_escolar(cod_empresa_transporte_escolar) MATCH SIMPLE ON UPDATE RESTRICT ON DELETE RESTRICT
)
WITH (
OIDS=TRUE
);

CREATE SEQUENCE modules.tipo_veiculo_seq
INCREMENT 1
MINVALUE 1
MAXVALUE 9223372036854775807
START 1
CACHE 1;
ALTER TABLE modules.tipo_veiculo_seq
OWNER TO ieducar;

CREATE TABLE modules.tipo_veiculo
(
cod_tipo_veiculo integer NOT NULL DEFAULT nextval('modules.tipo_veiculo_seq'::regclass),
descricao character varying(60),
CONSTRAINT tipo_veiculo_pkey PRIMARY KEY (cod_tipo_veiculo)
)
WITH (
OIDS=TRUE
);


CREATE SEQUENCE modules.veiculo_seq
INCREMENT 1
MINVALUE 1
MAXVALUE 9223372036854775807
START 1
CACHE 1;
ALTER TABLE modules.veiculo_seq
OWNER TO ieducar;

CREATE TABLE modules.veiculo
(
cod_veiculo integer NOT NULL DEFAULT nextval('modules.veiculo_seq'::regclass),
descricao character varying(255) NOT NULL,
placa character varying(10) NOT NULL,
renavam character varying(15) NOT NULL,
chassi character varying(30),
marca character varying(50),
ano_fabricacao integer,
ano_modelo integer,
passageiros integer NOT NULL,
malha char(1) NOT NULL,
ref_cod_tipo_veiculo integer NOT NULL,
exclusivo_transporte_escolar char(1) NOT NULL,
adaptado_necessidades_especiais char(1) NOT NULL,
ativo char(1),
descricao_inativo char(155),
ref_cod_empresa_transporte_escolar integer NOT NULL,
ref_cod_motorista integer NOT NULL,
observacao character varying(255),
CONSTRAINT veiculo_pkey PRIMARY KEY (cod_veiculo),
CONSTRAINT veiculo_ref_cod_empresa_transporte_escolar_fkey FOREIGN KEY (ref_cod_empresa_transporte_escolar)
REFERENCES modules.empresa_transporte_escolar(cod_empresa_transporte_escolar) MATCH SIMPLE,
CONSTRAINT veiculo_ref_cod_tipo_veiculo_fkey FOREIGN KEY (ref_cod_tipo_veiculo)
REFERENCES modules.tipo_veiculo(cod_tipo_veiculo) MATCH SIMPLE
ON UPDATE RESTRICT ON DELETE RESTRICT
)
WITH (
OIDS=TRUE
);

INSERT INTO modules.tipo_veiculo (cod_tipo_veiculo,descricao) values (1,'Vans/Kombis');
INSERT INTO modules.tipo_veiculo (cod_tipo_veiculo,descricao) values (2,'Microônibus');
INSERT INTO modules.tipo_veiculo (cod_tipo_veiculo,descricao) values (3,'Ônibus');
INSERT INTO modules.tipo_veiculo (cod_tipo_veiculo,descricao) values (4,'Bicicleta');
INSERT INTO modules.tipo_veiculo (cod_tipo_veiculo,descricao) values (5,'Tração Animal');
INSERT INTO modules.tipo_veiculo (cod_tipo_veiculo,descricao) values (6,'Outro');
INSERT INTO modules.tipo_veiculo (cod_tipo_veiculo,descricao) values (7,'Capacidade de até 5 Alunos');
INSERT INTO modules.tipo_veiculo (cod_tipo_veiculo,descricao) values (8,'Capacidade entre 5 a 15 Alunos');
INSERT INTO modules.tipo_veiculo (cod_tipo_veiculo,descricao) values (9,'Capacidade entre 15 a 35 Alunos');
INSERT INTO modules.tipo_veiculo (cod_tipo_veiculo,descricao) values (10,'Capacidade acima de 35 Alunos');
INSERT INTO modules.tipo_veiculo (cod_tipo_veiculo,descricao) values (11,'Trem/Metrô');"
 
 
echo -e "\n** Rodando migração 56_controle_das_rotas_transporte_escolar.sql"
 
~/.pgvm/environments/8.2.23/bin/psql -d ieducar -p 5433 -c "
  CREATE SEQUENCE modules.rota_transporte_escolar_seq
  INCREMENT 1
  MINVALUE 1
  MAXVALUE 9223372036854775807
  START 1
  CACHE 1;
  ALTER TABLE modules.rota_transporte_escolar_seq
  OWNER TO ieducar;

  CREATE TABLE modules.rota_transporte_escolar
  (
  cod_rota_transporte_escolar integer NOT NULL DEFAULT nextval('modules.rota_transporte_escolar_seq'::regclass),
  ref_idpes_destino integer NOT NULL,
  descricao character varying(50) NOT NULL,
  ano integer NOT NULL,
  tipo_rota char(1) NOT NULL,
  km_pav float,
  km_npav float,
  ref_cod_empresa_transporte_escolar integer,
  tercerizado character(1) not null,
  CONSTRAINT rota_transporte_escolar_cod_rota_transporte_escolar_pkey PRIMARY KEY (cod_rota_transporte_escolar ),
  CONSTRAINT rota_transporte_escolar_ref_idpes_destino_fkey FOREIGN KEY (ref_idpes_destino)
  REFERENCES cadastro.juridica (idpes) MATCH SIMPLE,
  CONSTRAINT rota_transporte_escolar_ref_cod_empresa_transporte_escolar_fkey FOREIGN KEY (ref_cod_empresa_transporte_escolar)
  REFERENCES modules.empresa_transporte_escolar (cod_empresa_transporte_escolar) MATCH SIMPLE
  ON UPDATE RESTRICT ON DELETE RESTRICT
  ) 
  WITH (
  OIDS=TRUE
  );
  
  CREATE SEQUENCE modules.itinerario_transporte_escolar_seq
  INCREMENT 1
  MINVALUE 1
  MAXVALUE 9223372036854775807
  START 1
  CACHE 1;
  ALTER TABLE modules.itinerario_transporte_escolar_seq
  OWNER TO ieducar;
  
  CREATE TABLE modules.itinerario_transporte_escolar
  (
  cod_itinerario_transporte_escolar integer NOT NULL DEFAULT nextval('modules.itinerario_transporte_escolar_seq'::regclass),
  ref_cod_rota_transporte_escolar integer not null,
  seq integer not null,
  ref_cod_ponto_transporte_escolar integer not null,
  ref_cod_veiculo integer,
  hora time without time zone,
  tipo character(1) not null,
  CONSTRAINT itinerario_transporte_escolar_cod_itinerario_transporte_escolar_pkey PRIMARY KEY (cod_itinerario_transporte_escolar),
  CONSTRAINT itinerario_transporte_escolar_ref_cod_rota_transporte_escolar_fkey FOREIGN KEY (ref_cod_rota_transporte_escolar)
  REFERENCES modules.rota_transporte_escolar (cod_rota_transporte_escolar) MATCH SIMPLE,
  CONSTRAINT ponto_transporte_escolar_ref_cod_veiculo_fkey FOREIGN KEY (ref_cod_veiculo)
  REFERENCES modules.veiculo (cod_veiculo) MATCH SIMPLE
  ON UPDATE RESTRICT ON DELETE RESTRICT
  )
  WITH (
  OIDS=TRUE
  );  
  
  CREATE SEQUENCE modules.ponto_transporte_escolar_seq
  INCREMENT 1
  MINVALUE 1
  MAXVALUE 9223372036854775807
  START 1
  CACHE 1;
  ALTER TABLE modules.ponto_transporte_escolar_seq
  OWNER TO ieducar;
  
  CREATE TABLE modules.ponto_transporte_escolar
  (
  cod_ponto_transporte_escolar integer NOT NULL DEFAULT nextval('modules.ponto_transporte_escolar_seq'::regclass),
  descricao varchar(70) not null,
  CONSTRAINT ponto_transporte_escolar_cod_ponto_transporte_escolar_pkey PRIMARY KEY (cod_ponto_transporte_escolar )
  )
  WITH (
  OIDS=TRUE
  );
  
  CREATE SEQUENCE modules.pessoa_transporte_seq
  INCREMENT 1
  MINVALUE 1
  MAXVALUE 9223372036854775807
  START 1
  CACHE 1;
  ALTER TABLE modules.pessoa_transporte_seq
  OWNER TO ieducar;
  
  CREATE TABLE modules.pessoa_transporte
  (
  cod_pessoa_transporte integer NOT NULL DEFAULT nextval('modules.pessoa_transporte_seq'::regclass),
  ref_idpes integer not null,
  ref_cod_rota_transporte_escolar integer not null,
  ref_cod_ponto_transporte_escolar integer,
  ref_idpes_destino integer,
  observacao varchar(255),
  CONSTRAINT pessoa_transporte_cod_pessoa_transporte_pkey PRIMARY KEY (cod_pessoa_transporte ),
  CONSTRAINT pessoa_transporte_ref_cod_rota_transporte_escolar_fkey FOREIGN KEY (ref_cod_rota_transporte_escolar)
  REFERENCES modules.rota_transporte_escolar (cod_rota_transporte_escolar) MATCH SIMPLE,
  CONSTRAINT pessoa_transporte_ref_cod_ponto_transporte_escolar_fkey FOREIGN KEY (ref_cod_ponto_transporte_escolar)
  REFERENCES modules.ponto_transporte_escolar (cod_ponto_transporte_escolar) MATCH SIMPLE,
  CONSTRAINT pessoa_transporte_ref_idpes_destino_fkey FOREIGN KEY (ref_idpes_destino)
  REFERENCES cadastro.juridica (idpes) MATCH SIMPLE,
  CONSTRAINT pessoa_transporte_ref_idpes_fkey FOREIGN KEY (ref_idpes)
  REFERENCES cadastro.fisica (idpes) MATCH SIMPLE
  ON UPDATE RESTRICT ON DELETE RESTRICT
  )
  WITH (
  OIDS=TRUE
  );
"
 
 
echo -e "\n** Rodando migração 57_menus_sql_modulo_transporte_escolar.sql"
 
~/.pgvm/environments/8.2.23/bin/psql -d ieducar -p 5433 -c "
INSERT INTO portal.menu_menu (cod_menu_menu, nm_menu) 
VALUES (69,'Transporte Escolar');
INSERT INTO portal.menu_submenu (cod_menu_submenu, ref_cod_menu_menu, cod_sistema, nm_submenu, arquivo, nivel) 
VALUES (21234, 69, 2, 'Apresentação', 'transporte_index.php', '2');
INSERT INTO pmicontrolesis.tutormenu (cod_tutormenu,nm_tutormenu) 
VALUES (17,'Transporte Escolar');
INSERT INTO pmicontrolesis.menu (cod_menu,tt_menu,ord_menu,alvo,suprime_menu,ref_cod_tutormenu,ref_cod_ico)
VALUES(20710,'Cadastros',1,'_self',1,17,1);
INSERT INTO pmicontrolesis.menu (cod_menu,tt_menu,ord_menu,alvo,suprime_menu,ref_cod_tutormenu,ref_cod_ico) 
VALUES(20711,'Movimentação',2,'_self',1,17,1);
INSERT INTO pmicontrolesis.menu (cod_menu,tt_menu,ord_menu,alvo,suprime_menu,ref_cod_tutormenu,ref_cod_ico) 
VALUES(20712,'Relatórios',3,'_self',1,17,1);
INSERT INTO portal.menu_submenu 
VALUES (21235, 69, 2, 'Empresas', 'transporte_empresa_lst.php',null,3); 
INSERT INTO portal.menu_submenu 
VALUES (21236, 69, 2, 'Motoristas', 'transporte_motorista_lst.php',null,3); 
INSERT INTO portal.menu_submenu 
VALUES (21237, 69, 2, 'Veículos', 'transporte_veiculo_lst.php',null,3); 
INSERT INTO portal.menu_submenu 
VALUES (21238, 69, 2, 'Rotas', 'transporte_rota_lst.php',null,3); 
INSERT INTO portal.menu_submenu 
VALUES (21239, 69, 2, 'Pontos', 'transporte_ponto_lst.php',null,3); 
INSERT INTO portal.menu_submenu 
VALUES (21240, 69, 2, 'Usuários de Transporte', 'transporte_pessoa_lst.php',null,3);
INSERT INTO pmicontrolesis.menu 
VALUES(21235,21235,20710,'Empresas',1,'transporte_empresa_lst.php','_self',1,17,192);

INSERT INTO pmicontrolesis.menu 
VALUES(21236,21236,20710,'Motoristas',2,'transporte_motorista_lst.php','_self',1,17,192);

INSERT INTO pmicontrolesis.menu 
VALUES(21237,21237,20710,'Veículos',3,'transporte_veiculo_lst.php','_self',1,17,192);

INSERT INTO pmicontrolesis.menu 
VALUES(21238,21238,20710,'Pontos',4,'transporte_ponto_lst.php','_self',1,17,192);

INSERT INTO pmicontrolesis.menu 
VALUES(21239,21239,20710,'Rotas',5,'transporte_rota_lst.php','_self',1,17,192);

INSERT INTO pmicontrolesis.menu 
VALUES(21240,21240,20711,'Usuários de Transporte',5,'transporte_pessoa_lst.php','_self',1,17,192);"

echo -e "\n** Rodando migração 58_insere_permissoes_admin_modulo_transporte.sql"

~/.pgvm/environments/8.2.23/bin/psql -d ieducar -p 5433 -c "

INSERT INTO portal.menu_funcionario (ref_ref_cod_pessoa_fj, cadastra, exclui, ref_cod_menu_submenu) VALUES (1, 1, 1, 21235);
INSERT INTO portal.menu_funcionario (ref_ref_cod_pessoa_fj, cadastra, exclui, ref_cod_menu_submenu) VALUES (1, 1, 1, 21236);
INSERT INTO portal.menu_funcionario (ref_ref_cod_pessoa_fj, cadastra, exclui, ref_cod_menu_submenu) VALUES (1, 1, 1, 21237);
INSERT INTO portal.menu_funcionario (ref_ref_cod_pessoa_fj, cadastra, exclui, ref_cod_menu_submenu) VALUES (1, 1, 1, 21238);
INSERT INTO portal.menu_funcionario (ref_ref_cod_pessoa_fj, cadastra, exclui, ref_cod_menu_submenu) VALUES (1, 1, 1, 21239);
INSERT INTO portal.menu_funcionario (ref_ref_cod_pessoa_fj, cadastra, exclui, ref_cod_menu_submenu) VALUES (1, 1, 1, 21240);
"

echo -e "\n** Rodando migração 59_altera_nome_menu_corrige_bug_pessoa.sql"

~/.pgvm/environments/8.2.23/bin/psql -d ieducar -p 5433 -c "
UPDATE portal.menu_menu SET nm_menu = 'Pessoa FJ' WHERE cod_menu_menu = 7;"

echo -e "\n** Rodando migração 60_cria_funcao_copia_notas_trasnf.sql"

~/.pgvm/environments/8.2.23/bin/psql -d ieducar -p 5433 -c "
  CREATE OR REPLACE FUNCTION modules.copia_notas_transf(old_matricula_id integer, new_matricula_id integer)
  RETURNS VARCHAR AS
  \$BODY\$
  DECLARE
  cur_comp RECORD;
  cur_comp_media RECORD;
  cur_falta_geral RECORD;
  cur_falta_comp RECORD;
  cur_parecer_geral RECORD;
  cur_parecer_comp RECORD;
  v_tipo_nota integer;
  v_tipo_parecer integer;
  v_tipo_falta integer;
  v_nota_id integer;
  v_old_nota_id integer;
  v_falta_id integer;
  v_old_falta_id integer;
  v_parecer_id integer;
  v_old_parecer_id integer;
  begin

  /* VERIFICA SE AS MATRICULAS FAZEM PARTE DO MESMO ANO LETIVO*/
  IF ((SELECT eal.ano FROM pmieducar.escola_ano_letivo eal
        INNER JOIN pmieducar.matricula mat ON (mat.ref_ref_cod_escola = eal.ref_cod_escola)
         WHERE mat.cod_matricula = old_matricula_id and eal.andamento = 1 limit 1) = (SELECT eal.ano FROM pmieducar.escola_ano_letivo eal
                                        INNER JOIN pmieducar.matricula mat ON (mat.ref_ref_cod_escola = eal.ref_cod_escola)
                                         WHERE mat.cod_matricula = new_matricula_id and eal.andamento = 1 limit 1) ) THEN


    IF (
     (  CASE WHEN (select padrao_ano_escolar from pmieducar.curso 
        where cod_curso = (select ref_cod_curso from pmieducar.matricula 
        where cod_matricula = new_matricula_id)) = 1
       THEN  (select max(sequencial) as qtd_etapa from pmieducar.ano_letivo_modulo mod
        inner join pmieducar.matricula mat on (mat.ref_ref_cod_escola = mod.ref_ref_cod_escola)
                    where mat.cod_matricula = new_matricula_id)
             ELSE (select count(ref_cod_modulo) from pmieducar.turma_modulo
        where ref_cod_turma = (select ref_cod_turma from pmieducar.matricula_turma 
        where ref_cod_matricula = new_matricula_id))
             END
   ) = (CASE WHEN (select padrao_ano_escolar from pmieducar.curso 
        where cod_curso = (select ref_cod_curso from pmieducar.matricula 
        where cod_matricula = old_matricula_id)) = 1
       THEN  (select max(sequencial) as qtd_etapa from pmieducar.ano_letivo_modulo mod
              inner join pmieducar.matricula mat on (mat.ref_ref_cod_escola = mod.ref_ref_cod_escola)
                    where mat.cod_matricula = old_matricula_id)
             ELSE  (select count(ref_cod_modulo) from pmieducar.turma_modulo
        where ref_cod_turma = (select ref_cod_turma from pmieducar.matricula_turma 
        where ref_cod_matricula = old_matricula_id))
             END
        )
  ) THEN

   -- IF (TRUE) THEN
      /* VERIFICA SE UTILIZAM A MESMA REGRA DE AVALIAÇÃO*/
      IF ((SELECT id FROM modules.regra_avaliacao rg
          INNER JOIN pmieducar.serie s ON (rg.id = s.regra_avaliacao_id)
          INNER JOIN pmieducar.matricula m ON (s.cod_serie = m.ref_ref_cod_serie)
          where m.cod_matricula = old_matricula_id ) = 
            (SELECT id FROM modules.regra_avaliacao rg
              INNER JOIN pmieducar.serie s ON (rg.id = s.regra_avaliacao_id)
              INNER JOIN pmieducar.matricula m ON (s.cod_serie = m.ref_ref_cod_serie)
              where m.cod_matricula = new_matricula_id ) ) THEN


        v_tipo_nota := (SELECT tipo_nota FROM modules.regra_avaliacao rg
                  INNER JOIN pmieducar.serie s ON (rg.id = s.regra_avaliacao_id)
                  INNER JOIN pmieducar.matricula m ON (s.cod_serie = m.ref_ref_cod_serie)
                  where m.cod_matricula = old_matricula_id);

        v_tipo_falta := (SELECT tipo_presenca FROM modules.regra_avaliacao rg
                  INNER JOIN pmieducar.serie s ON (rg.id = s.regra_avaliacao_id)
                  INNER JOIN pmieducar.matricula m ON (s.cod_serie = m.ref_ref_cod_serie)
                  where m.cod_matricula = old_matricula_id);

        v_tipo_parecer := (SELECT parecer_descritivo FROM modules.regra_avaliacao rg
                  INNER JOIN pmieducar.serie s ON (rg.id = s.regra_avaliacao_id)
                  INNER JOIN pmieducar.matricula m ON (s.cod_serie = m.ref_ref_cod_serie)
                  where m.cod_matricula = old_matricula_id);
        /* SE A REGRA UTILIZAR NOTA, COPIA AS NOTAS*/
        IF (v_tipo_nota >0) THEN

          INSERT INTO modules.nota_aluno (matricula_id)VALUES (new_matricula_id);
          v_nota_id := (SELECT max(id) FROM modules.nota_aluno WHERE matricula_id = new_matricula_id);

          v_old_nota_id := (SELECT max(id) FROM modules.nota_aluno WHERE matricula_id = old_matricula_id);

          FOR cur_comp IN (SELECT * FROM modules.nota_componente_curricular where nota_aluno_id = v_old_nota_id) LOOP
            INSERT INTO modules.nota_componente_curricular (nota_aluno_id,componente_curricular_id,nota,nota_arredondada,etapa)
            VALUES(v_nota_id,cur_comp.componente_curricular_id,cur_comp.nota,cur_comp.nota_arredondada,cur_comp.etapa);
          END LOOP;

          FOR cur_comp_media IN (SELECT * FROM modules.nota_componente_curricular_media where nota_aluno_id = v_old_nota_id) LOOP
            INSERT INTO modules.nota_componente_curricular_media (nota_aluno_id,componente_curricular_id,media,media_arredondada,etapa)
            VALUES(v_nota_id,cur_comp_media.componente_curricular_id,cur_comp_media.media,cur_comp_media.media_arredondada,cur_comp_media.etapa);
          END LOOP;
        END IF;

        IF (v_tipo_falta = 1) THEN

            INSERT INTO modules.falta_aluno (matricula_id, tipo_falta) VALUES (new_matricula_id,1);
            v_falta_id = (SELECT max(id) FROM modules.falta_aluno WHERE matricula_id = new_matricula_id);
          v_old_falta_id := (SELECT max(id) FROM modules.falta_aluno WHERE matricula_id = old_matricula_id);

          FOR cur_falta_geral IN (SELECT * FROM modules.falta_geral where falta_aluno_id = v_old_falta_id) LOOP
            INSERT INTO modules.falta_geral (falta_aluno_id,quantidade,etapa)
            VALUES(v_falta_id,cur_falta_geral.quantidade, cur_falta_geral.etapa);
          END LOOP;
        END IF;

        IF (v_tipo_falta = 2) THEN

          INSERT INTO modules.falta_aluno (matricula_id, tipo_falta) VALUES (new_matricula_id,2);
          v_falta_id = (SELECT max(id) FROM modules.falta_aluno WHERE matricula_id = new_matricula_id);
          v_old_falta_id := (SELECT max(id) FROM modules.falta_aluno WHERE matricula_id = old_matricula_id);

          FOR cur_falta_comp IN (SELECT * FROM modules.falta_componente_curricular where falta_aluno_id = v_old_falta_id) LOOP
            INSERT INTO modules.falta_componente_curricular (falta_aluno_id,componente_curricular_id,quantidade,etapa)
            VALUES(v_falta_id,cur_falta_comp.componente_curricular_id,cur_falta_comp.quantidade, cur_falta_comp.etapa);
          END LOOP;
        END IF;

        IF (v_tipo_parecer = 2) THEN

          INSERT INTO modules.parecer_aluno (matricula_id, parecer_descritivo)VALUES (new_matricula_id,2);
          v_parecer_id := (SELECT max(id) FROM modules.parecer_aluno WHERE matricula_id = new_matricula_id);
          v_old_parecer_id := (SELECT max(id) FROM modules.parecer_aluno WHERE matricula_id = old_matricula_id);

          FOR cur_parecer_comp IN (SELECT * FROM modules.parecer_componente_curricular where parecer_aluno_id = v_old_parecer_id) LOOP
            INSERT INTO modules.parecer_componente_curricular (parecer_aluno_id,componente_curricular_id,parecer,etapa)
            VALUES(v_parecer_id,cur_parecer_comp.componente_curricular_id,cur_parecer_comp.parecer, cur_parecer_comp.etapa);
          END LOOP;
        END IF;

        IF (v_tipo_parecer = 3) THEN

          INSERT INTO modules.parecer_aluno (matricula_id, parecer_descritivo)VALUES (new_matricula_id,3);
          v_parecer_id := (SELECT max(id) FROM modules.parecer_aluno WHERE matricula_id = new_matricula_id);
          v_old_parecer_id := (SELECT max(id) FROM modules.parecer_aluno WHERE matricula_id = old_matricula_id);

          FOR cur_parecer_geral IN (SELECT * FROM modules.parecer_geral where parecer_aluno_id = v_old_parecer_id) LOOP
            INSERT INTO modules.parecer_geral (parecer_aluno_id,parecer,etapa)
            VALUES(v_parecer_id,cur_parecer_geral.parecer, cur_parecer_geral.etapa);
          END LOOP;
        END IF;

      ELSE RETURN 'REGRA AVALIACAO DIFERENTE'; END IF;
    ELSE RETURN 'ETAPA DIFERENTE'; END IF;
  RETURN '';
  END IF;

  end;\$BODY\$
  LANGUAGE plpgsql VOLATILE;
  ALTER FUNCTION modules.copia_notas_transf(integer, integer)
  OWNER TO ieducar;"

echo -e "\n** Rodando migração 61_cria_ficha_medica_aluno.sql"

~/.pgvm/environments/8.2.23/bin/psql -d ieducar -p 5433 -c "
  CREATE TABLE modules.ficha_medica_aluno
  (
  ref_cod_aluno integer NOT NULL,
  altura character(4),
  peso character(7),
  grupo_sanguineo character(2),
  fator_rh character(1),
  alergia_medicamento character(1),
  desc_alergia_medicamento character varying(100),
  alergia_alimento character(1),
  desc_alergia_alimento character varying(100),
  doenca_congenita character(1),
  desc_doenca_congenita character varying(100),
  fumante character(1),
  doenca_caxumba character(1),
  doenca_sarampo character(1),
  doenca_rubeola character(1),
  doenca_catapora character(1),
  doenca_escarlatina character(1),
  doenca_coqueluche character(1),
  doenca_outras character varying(100),
  epiletico character(1),
  epiletico_tratamento character(1),
  hemofilico character(1),
  hipertenso character(1),
  asmatico character(1),
  diabetico character(1),
  insulina character(1),
  tratamento_medico character(1),
  desc_tratamento_medico character varying(100),
  medicacao_especifica character(1),
  desc_medicacao_especifica character varying(100),
  acomp_medico_psicologico character(1),
  desc_acomp_medico_psicologico character varying(100),
  restricao_atividade_fisica character(1),
  desc_restricao_atividade_fisica character varying(100),
  fratura_trauma character(1),
  desc_fratura_trauma character varying(100),
  plano_saude character(1),
  desc_plano_saude character varying(50),
  hospital_clinica character varying(100),
  hospital_clinica_endereco character varying(50),
  hospital_clinica_telefone character varying(20),
  responsavel character varying(50),
  responsavel_parentesco character varying(20),
  responsavel_parentesco_telefone character varying(20),
  responsavel_parentesco_celular character varying(20),
  observacao character varying(255),
  CONSTRAINT ficha_medica_cod_aluno_pkey PRIMARY KEY (ref_cod_aluno),
  CONSTRAINT ficha_medica_aluno_fkey FOREIGN KEY (ref_cod_aluno)
  REFERENCES pmieducar.aluno(cod_aluno) MATCH SIMPLE
  ON UPDATE RESTRICT ON DELETE RESTRICT
  )
  WITH (
  OIDS=TRUE
  );"

  echo -e "\n** Rodando migração 62_cria_uniforme_escolar.sql"

~/.pgvm/environments/8.2.23/bin/psql -d ieducar -p 5433 -c "
  CREATE TABLE modules.uniforme_aluno
  (
  ref_cod_aluno integer NOT NULL,
  recebeu_uniforme character(1),
  quantidade_camiseta integer,
  tamanho_camiseta character(2),
  quantidade_blusa_jaqueta integer,
  tamanho_blusa_jaqueta character(2),
  quantidade_bermuda integer,
  tamanho_bermuda character(2),
  quantidade_calca integer,
  tamanho_calca character(2),
  quantidade_saia integer,
  tamanho_saia character(2),
  quantidade_calcado integer,
  tamanho_calcado character(2),
  quantidade_meia integer,
  tamanho_meia character(2),
  CONSTRAINT uniforme_aluno_pkey PRIMARY KEY (ref_cod_aluno),
  CONSTRAINT uniforme_aluno_fkey FOREIGN KEY (ref_cod_aluno)
  REFERENCES pmieducar.aluno(cod_aluno) MATCH SIMPLE
  ON UPDATE RESTRICT ON DELETE RESTRICT
  )
  WITH (
  OIDS=TRUE
  );"

  echo -e "\n** Rodando migração 63_cria_tabela_moradia_aluno.sql"

~/.pgvm/environments/8.2.23/bin/psql -d ieducar -p 5433 -c "
  CREATE TABLE modules.moradia_aluno
  (
  ref_cod_aluno integer NOT NULL,
  moradia character(1),
  material character(1) DEFAULT ('A'),
  casa_outra character varying(20),
  moradia_situacao integer,
  quartos integer,
  sala integer,
  copa integer,
  banheiro integer,
  garagem integer,
  empregada_domestica character(1),
  automovel character(1),
  motocicleta character(1),
  computador character(1),
  geladeira character(1),
  fogao character(1),
  maquina_lavar character(1),
  microondas character(1),
  video_dvd character(1),
  televisao character(1),
  celular character(1),
  telefone character(1),
  quant_pessoas integer,
  renda double precision,
  agua_encanada character(1),
  poco character(1),
  energia character(1),
  esgoto character(1),
  fossa character(1),
  lixo character(1),
  CONSTRAINT moradia_aluno_pkei PRIMARY KEY (ref_cod_aluno),
  CONSTRAINT moradia_aluno_fkey FOREIGN KEY (ref_cod_aluno)
  REFERENCES pmieducar.aluno(cod_aluno) MATCH SIMPLE
  ON UPDATE RESTRICT ON DELETE RESTRICT
  )
  WITH (
  OIDS=TRUE
  );"

echo -e "\n** Rodando migração 64_cria_function_frequencia_geral.sql"

~/.pgvm/environments/8.2.23/bin/psql -d ieducar -p 5433 -c "

CREATE OR REPLACE FUNCTION modules.frequencia_da_matricula(p_matricula_id integer)
  RETURNS FLOAT AS
  \$BODY\$
  DECLARE 
  v_regra_falta integer;
  v_falta_aluno_id  integer;
  v_qtd_dias_letivos_serie integer;
  v_total_faltas integer;
  v_qtd_horas_serie integer;
  v_hora_falta FLOAT;
  begin 

  /*
    regra_falta: 
    1- Global
    2- Por componente
  */
  v_regra_falta:= (SELECT rg.tipo_presenca FROM modules.regra_avaliacao rg
            INNER JOIN pmieducar.serie s ON (rg.id = s.regra_avaliacao_id)
            INNER JOIN pmieducar.matricula m ON (s.cod_serie = m.ref_ref_cod_serie)
            where m.cod_matricula = p_matricula_id);

    v_falta_aluno_id := ( SELECT id FROM modules.falta_aluno WHERE matricula_id = p_matricula_id ORDER BY id DESC LIMIT 1 );

  IF (v_regra_falta = 1) THEN

    v_qtd_dias_letivos_serie := (SELECT s.dias_letivos 
                    FROM pmieducar.serie s 
                    INNER JOIN pmieducar.matricula m ON (m.ref_ref_cod_serie = s.cod_serie) 
                    WHERE m.cod_matricula = p_matricula_id);

    v_total_faltas := ( SELECT SUM(quantidade) FROM falta_geral WHERE falta_aluno_id = v_falta_aluno_id);

    RETURN (((v_qtd_dias_letivos_serie - v_total_faltas) * 100 ) / v_qtd_dias_letivos_serie );

  ELSE
    
    v_qtd_horas_serie := ( SELECT s.carga_horaria 
                    FROM pmieducar.serie s 
                    INNER JOIN pmieducar.matricula m ON (m.ref_ref_cod_serie = s.cod_serie) 
                    WHERE m.cod_matricula = p_matricula_id);
    
    v_total_faltas := ( SELECT SUM(quantidade) FROM falta_componente_curricular WHERE falta_aluno_id = v_falta_aluno_id);

    v_hora_falta := (SELECT hora_falta FROM pmieducar.curso c 
              INNER JOIN pmieducar.matricula m ON (c.cod_curso = m.ref_cod_curso)
              WHERE m.cod_matricula = p_matricula_id);

    RETURN  (100 - ((v_total_faltas * (v_hora_falta*100))/v_qtd_horas_serie));

  END IF;

  end;\$BODY\$
  LANGUAGE 'plpgsql' VOLATILE;"

echo -e "\n** Rodando migração 65_altera_menu_lancamento_notas.sql"

~/.pgvm/environments/8.2.23/bin/psql -d ieducar -p 5433 -c "
  DELETE FROM pmicontrolesis.menu WHERE cod_menu IN (643,644);
  DELETE FROM menu_tipo_usuario WHERE ref_cod_menu_submenu IN (643,644);
  DELETE FROM menu_funcionario WHERE ref_cod_menu_submenu IN (643,644);
  DELETE FROM portal.menu_submenu WHERE cod_menu_submenu IN (644,643);
  UPDATE portal.menu_submenu SET arquivo = 'module/Avaliacao/diario' WHERE cod_menu_submenu = 642;
  UPDATE pmicontrolesis.menu SET caminho = 'module/Avaliacao/diario' WHERE cod_menu = 21152;"

echo -e "\n** Rodando migração 66_cria_colunas_data_processos_matricula.sql"

~/.pgvm/environments/8.2.23/bin/psql -d ieducar -p 5433 -c "

  ALTER TABLE pmieducar.matricula ADD COLUMN data_matricula timestamp without time zone;
  ALTER TABLE pmieducar.matricula ADD COLUMN data_cancel timestamp without time zone;
 
  CREATE OR REPLACE FUNCTION retira_data_cancel_matricula_fun()
  RETURNS trigger AS
  \$func\$
  BEGIN

  UPDATE pmieducar.matricula
  SET    data_cancel = NULL
  WHERE  cod_matricula = new.cod_matricula
  AND    data_cancel IS DISTINCT FROM NULL
  AND    aprovado = 3 
  AND (SELECT 1 FROM pmieducar.transferencia_solicitacao WHERE ativo = 1 AND ref_cod_matricula_saida = new.cod_matricula limit 1) is null;

  RETURN NULL;
  END
  \$func\$  LANGUAGE plpgsql;

  CREATE TRIGGER retira_data_cancel_matricula_trg
  AFTER UPDATE ON pmieducar.matricula
  FOR EACH ROW
  EXECUTE PROCEDURE retira_data_cancel_matricula_fun();"

echo -e "\n** Rodando migração 67_cria_coluna_data_enturmacao.sql"

~/.pgvm/environments/8.2.23/bin/psql -d ieducar -p 5433 -c "

  ALTER TABLE pmieducar.matricula_turma 
  add COLUMN data_enturmacao date;

  UPDATE pmieducar.matricula_turma set data_enturmacao = data_cadastro;"

echo -e "\n** Rodando migração 68_cria_processo_fechamento_turma.sql"

~/.pgvm/environments/8.2.23/bin/psql -d ieducar -p 5433 -c "

  ALTER TABLE pmieducar.matricula_turma ALTER COLUMN data_enturmacao SET NOT NULL; 

  ALTER TABLE pmieducar.matricula_turma 
  add COLUMN sequencial_fechamento INTEGER NOT NULL default 0;  

  ALTER TABLE pmieducar.turma 
  add COLUMN data_fechamento date;"

echo -e "\n** Rodando migração 69_cria_function_calcular_data_prevista_emprestimo.sql"

~/.pgvm/environments/8.2.23/bin/psql -d ieducar -p 5433 -c "

  CREATE OR REPLACE FUNCTION modules.preve_data_emprestimo(biblioteca_id integer, data_prevista date)
    RETURNS date AS
  \$BODY\$
  DECLARE 
  begin           
  
  IF (( select 1 from pmieducar.biblioteca_dia WHERE ref_cod_biblioteca = biblioteca_id AND dia = ((SELECT EXTRACT(DOW FROM data_prevista))+1) limit 1) IS NOT null) THEN    
    IF ((SELECT 1 FROM pmieducar.biblioteca_feriados WHERE ref_cod_biblioteca = biblioteca_id and data_feriado = data_prevista) IS NULL) THEN
      RETURN data_prevista;
    ELSE
      RETURN modules.preve_data_emprestimo(biblioteca_id, data_prevista+1);
    END IF;
  ELSE
    RETURN modules.preve_data_emprestimo(biblioteca_id, data_prevista+1);
  END IF;

  end;\$BODY\$
    LANGUAGE 'plpgsql' VOLATILE;"

echo -e "\n** Rodando migração 70_retira_deficiencia_nenhuma.sql"

~/.pgvm/environments/8.2.23/bin/psql -d ieducar -p 5433 -c "
  UPDATE pmieducar.servidor SET ref_cod_deficiencia = NULL where ref_cod_deficiencia = 1;
  DELETE FROM cadastro.fisica_deficiencia WHERE ref_cod_deficiencia = 1;
  DELETE FROM cadastro.deficiencia WHERE cod_deficiencia = 1;"

echo -e "\n** Rodando migração 71_cria_tabela_nota_exame.sql"

~/.pgvm/environments/8.2.23/bin/psql -d ieducar -p 5433 -c "

  CREATE TABLE modules.nota_exame
  (
  ref_cod_matricula integer NOT NULL,
  ref_cod_componente_curricular integer NOT NULL,
  nota_exame numeric(5,3),  
  CONSTRAINT moradia_aluno_fkey FOREIGN KEY (ref_cod_matricula)
  REFERENCES pmieducar.matricula(cod_matricula) MATCH SIMPLE
  ON UPDATE RESTRICT ON DELETE RESTRICT
  )
  WITH (
  OIDS=TRUE
  ); "
  
  
  
  
  ---------------------------------------------------------------------------------------------------
