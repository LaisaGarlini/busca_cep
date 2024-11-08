import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_fonts/google_fonts.dart';

void main() => runApp(BuscaCepApp());

class BuscaCepApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Busca CEP',
      theme: ThemeData(
        primarySwatch: Colors.purple,
        textTheme: GoogleFonts.firaSansTextTheme(
          Theme.of(context).textTheme,
        ),
      ),
      home: HomeScreen(),
    );
  }
}

// Tela principal do app onde o usuário vai buscar o CEP
class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    HomePage(),
    HistoricoPage(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Busca CEP')),
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        items: [
          BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Buscar CEP'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'Histórico'),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}

// Tela para buscar o CEP
class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _cepController = TextEditingController();
  Map<String, dynamic>? _address;
  bool _isLoading = false;
  String _errorMessage = '';

  // Função para buscar o endereço com o CEP fornecido
  Future<void> fetchAddress(String cep) async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final response = await http.get(Uri.parse('https://viacep.com.br/ws/$cep/json/'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // Se o CEP não for encontrado
        if (data.containsKey('erro') && data['erro'] == true) {
          setState(() {
            _errorMessage = 'CEP não encontrado!';
            _address = null;
          });
        } else {
          setState(() {
            _address = data;
            _errorMessage = '';
          });
          _salvaHistorico(data);
        }
      } else {
        throw Exception('Falha ao carregar endereço');
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Erro ao buscar o endereço';
        _address = null;
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Função para salvar o endereço no histórico local
  Future<void> _salvaHistorico(Map<String, dynamic> addressData) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> historico = prefs.getStringList('historico') ?? [];

    historico.add(json.encode(addressData));
    await prefs.setStringList('historico', historico);
  }

  // Função para abrir o endereço no Google Maps
  Future<void> _openInGoogleMaps() async {
    if (_address == null) return;

    final query = Uri.encodeComponent('${_address!['logradouro']}, ${_address!['localidade']}, ${_address!['uf']}');
    final url = 'https://www.google.com/maps/search/?api=1&query=$query';

    if (await canLaunch(url)) {
      await launch(url);
    } else {
      throw 'Não foi possível abrir o Google Maps';
    }
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    double containerWidth = screenWidth > 600 ? screenWidth * 0.5 : screenWidth;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Container(
          width: containerWidth,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Digite o CEP',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              // Campo para digitar o CEP
              Container(
                child: TextFormField(
                  controller: _cepController,
                  decoration: InputDecoration(
                    labelText: 'CEP',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                ),
              ),
              SizedBox(height: 16),
              // Botão para buscar o CEP
              ElevatedButton(
                onPressed: () => fetchAddress(_cepController.text),
                child: _isLoading ? CircularProgressIndicator() : Text('Buscar Endereço'),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 16),
                ),
              ),
              SizedBox(height: 20),
              // Exibe mensagem de erro se houver
              if (_errorMessage.isNotEmpty)
                Text(
                  _errorMessage,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.red, fontSize: 18, fontWeight: FontWeight.bold),
                ),
              // Exibe o endereço encontrado
              if (_address != null) ...[
                Card(
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('Endereço Encontrado:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        Text('CEP: ${_address!['cep']}'),
                        Text('Logradouro: ${_address!['logradouro']}'),
                        Text('Bairro: ${_address!['bairro']}'),
                        Text('Cidade: ${_address!['localidade']}'),
                        Text('Estado: ${_address!['uf']}'),
                        SizedBox(height: 10),
                        ElevatedButton(
                          onPressed: _openInGoogleMaps,
                          child: Text('Ver no Google Maps'),
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// Tela para mostrar o histórico de buscas
class HistoricoPage extends StatefulWidget {
  @override
  _HistoricoPageState createState() => _HistoricoPageState();
}

class _HistoricoPageState extends State<HistoricoPage> {
  List<Map<String, dynamic>> _historicoList = [];

  // Carrega o histórico quando a tela é carregada
  @override
  void initState() {
    super.initState();
    _carregarHistorico();
  }

  Future<void> _carregarHistorico() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> historico = prefs.getStringList('historico') ?? [];

    setState(() {
      _historicoList = historico.map((item) => json.decode(item) as Map<String, dynamic>).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    double containerWidth = screenWidth > 600 ? screenWidth * 0.5 : screenWidth;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center, // Centraliza verticalmente
          children: [
            Text(
              'Histórico de Buscas',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 20),
            // Envolva o ListView com Expanded para garantir que ele ocupe o espaço necessário
            Expanded(
              child: Container(
                width: containerWidth,
                child: ListView.builder(
                  padding: EdgeInsets.all(16),
                  itemCount: _historicoList.length,
                  itemBuilder: (context, index) {
                    final item = _historicoList[index];
                    return Card(
                      child: ListTile(
                        title: Text('CEP: ${item['cep']}'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Logradouro: ${item['logradouro']}'),
                            Text('Cidade: ${item['localidade']}, ${item['uf']}'),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}